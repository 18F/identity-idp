#!/usr/bin/env python3
"""Regenerate the delegated-access skill's indexes from docs/delegated-access-functional-requirements.md and git.

The document has one section per feature branch (sections 1 to 14, in stack order), section 15 for the
base branch and the work outside this repository, section 16 for the decisions log, and Appendix A for
the traceability matrix. This script parses the branch sections (number, branch, title), their
functional requirement rows (`| **FR-XXX-n** | … |`) and protocol rows (`| **EXC-n** | … |`), their
Decisions lists (`- **Dnn** …`), the section 15 rows, the decisions log (`NN. **Dnn — Title.**` under dated
`##` subsections) and the skill's hand-written `references/foundation.yml`.

Outputs (all under .claude/skills/login-delegated-access/references/ unless stated):
  requirements-index.md  every FR id, protocol id and D-number -> section, branch, line in the document
  traceability.md        FR row -> section and branch -> protocol rows -> decisions; protocol rows by prefix;
                         rows owned by section 15; foundation items per section
  decisions.md           D-numbers with their dated subsection, line and the sections that cite them
  branches.md            the stack as git sees it (tips, parents, commits with FR ids, directories touched)
  Appendix A body        between `<!-- traceability:begin -->` and `<!-- traceability:end -->` in the document

Usage:
  build_index.py            regenerate everything, print a one-line summary
  build_index.py --check    recompute without writing; exit 1 with a per-file summary if anything on disk
                            differs (the base sha in the header line is ignored)

Standard library only. Run from anywhere inside the repository.
"""

import argparse
import difflib
import os
import re
import subprocess
import sys
from collections import OrderedDict, defaultdict

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SKILL_DIR = os.path.dirname(SCRIPT_DIR)
REFS_DIR = os.path.join(SKILL_DIR, 'references')
SKILL_REL = '.claude/skills/login-delegated-access'
BASE_BRANCH = 'login-delegated-access'

DOC = 'docs/delegated-access-functional-requirements.md'
BASE_SECTION = '15'
LOG_SECTION = '16'
BASE_OWNER = 'base branch / outside the repository'

BEGIN = '<!-- traceability:begin -->'
END = '<!-- traceability:end -->'

HEADING = re.compile(r'^(#{1,6})\s+(.*?)\s*$')
BRANCH_HEADING = re.compile(r'^(\d+)\.\s+`([a-z0-9-]+)`:\s+(.*)$')
NUMBERED_HEADING = re.compile(r'^(\d+)\.\s+(.*)$')
SUBSECTION_HEADING = re.compile(r'^(\d+\.\d+)\s+(.*)$')
TABLE_ROW = re.compile(r'^\|\s*\*\*((?:FR-)?[A-Z]{1,5}(?:-[A-Z]{2,5})?-\d+[a-z]?|E\d+)\*\*\s*(\([^)|]*\))?\s*\|\s*(.*?)\s*\|\s*$')
DECISION_BULLET = re.compile(r'^-\s+\*\*(D\d+)\*\*\s+(.*)$')
DECISION_ENTRY = re.compile(r'^\d+\.\s+\*\*(D\d+)\s+[—–-]+\s+(.*?)\*\*')
FR_ID = re.compile(r'\bFR-[A-Z]{2,5}-\d+\b')
FR_RANGE = re.compile(r'\b(FR-[A-Z]{2,5})-(\d+)\s+to\s+\1-(\d+)\b')
ROW_ID = re.compile(r'\b([A-Z]{2,5}(?:-[A-Z]{2,5})?)-(\d+)([a-z]?)\b')
ROW_RANGE = re.compile(r'\b([A-Z]{2,5}(?:-[A-Z]{2,5})?)-(\d+)(?:\.\.(\d+)|\s+to\s+\1-(\d+))\b')
D_ID = re.compile(r'(?<![A-Za-z])D(\d+)(?:\s*(?:[–-]|to)\s*D(\d+))?\b')


# --------------------------------------------------------------------------- helpers

def run_git(*args, default=None):
    try:
        out = subprocess.run(['git', *args], capture_output=True, text=True, check=True)
        return out.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return default


def find_root():
    root = run_git('rev-parse', '--show-toplevel')
    if root and os.path.isfile(os.path.join(root, DOC)):
        return root
    here = SKILL_DIR
    while here != os.path.dirname(here):
        if os.path.isfile(os.path.join(here, DOC)):
            return here
        here = os.path.dirname(here)
    sys.exit(f'cannot find the repository root ({DOC})')


def natural_key(identifier):
    return [int(part) if part.isdigit() else part for part in re.split(r'(\d+)', identifier)]


def sorted_ids(ids):
    return sorted(set(ids), key=natural_key)


def expand_fr(text):
    """FR identifiers in text, with `FR-X-1 to FR-X-9` ranges expanded."""
    ids = []
    for prefix, lo, hi in FR_RANGE.findall(text):
        ids.extend(f'{prefix}-{n}' for n in range(int(lo), int(hi) + 1))
    ids.extend(FR_ID.findall(text))
    return sorted_ids(ids)


def expand_rows(text, known_prefixes):
    """Protocol row identifiers in text (ONB-1, EXC-17..19, CON-1 to CON-5), limited to known prefixes."""
    text = FR_ID.sub(' ', text)
    text = re.sub(r'\bRFC\s*\d+\b', ' ', text)
    ids = []
    for prefix, lo, hi_dots, hi_to in ROW_RANGE.findall(text):
        if prefix in known_prefixes:
            hi = hi_dots or hi_to
            ids.extend(f'{prefix}-{n}' for n in range(int(lo), int(hi) + 1))
    for prefix, num, suffix in ROW_ID.findall(text):
        if prefix in known_prefixes:
            ids.append(f'{prefix}-{num}{suffix}')
    return sorted_ids(ids)


def expand_decisions(text):
    ids = []
    for lo, hi in D_ID.findall(text):
        if hi:
            ids.extend(f'D{n}' for n in range(int(lo), int(hi) + 1))
        else:
            ids.append(f'D{lo}')
    return sorted_ids(ids)


def join(ids, empty='—'):
    ids = list(ids)
    return ', '.join(ids) if ids else empty


def compress(ids, empty='—'):
    """Identifier list with consecutive numbers collapsed: FR-ONB-1..9, CON-1..19, D1..D3."""
    groups = OrderedDict()
    for identifier in sorted_ids(ids):
        match = re.match(r'^(.*?)(\d+)$', identifier)
        if not match:
            groups.setdefault(identifier, [])
            continue
        groups.setdefault(match.group(1), []).append(int(match.group(2)))
    parts = []
    for prefix, numbers in groups.items():
        if not numbers:
            parts.append(prefix)
            continue
        start = previous = numbers[0]
        for number in numbers[1:] + [None]:
            if number is not None and number == previous + 1:
                previous = number
                continue
            parts.append(f'{prefix}{start}' if start == previous else f'{prefix}{start}..{previous}')
            if number is not None:
                start = previous = number
    return ', '.join(parts) if parts else empty


def cell(text):
    return str(text).replace('|', '\\|').replace('\n', ' ')


def row_prefix(row_id):
    return re.sub(r'-\d+[a-z]?$', '', row_id)


# --------------------------------------------------------------------------- document model

class Document:
    def __init__(self, root, rel, text=None):
        self.rel = rel
        self.path = os.path.join(root, rel)
        if text is None:
            with open(self.path, encoding='utf-8') as handle:
                text = handle.read()
        self.text = text
        # The generated Appendix A body is blanked (line count preserved) so the parser never reads its own output.
        self.lines = []
        in_generated = False
        for line in self.text.split('\n'):
            if line.strip() == BEGIN:
                in_generated = True
            elif line.strip() == END:
                in_generated = False
            self.lines.append('' if in_generated else line)
        self.headings = []  # (line_no, level, text)
        in_code = False
        for i, line in enumerate(self.lines, 1):
            if line.startswith('```'):
                in_code = not in_code
                continue
            if in_code:
                continue
            match = HEADING.match(line)
            if match:
                self.headings.append((i, len(match.group(1)), match.group(2)))

    def nearest_heading_of_level(self, line_no, level):
        best = None
        for number, lvl, text in self.headings:
            if number > line_no:
                break
            if lvl == level:
                best = text
        return best or ''

    def section_body(self, start_line, same_or_higher_level):
        """(1-based line number, text) pairs from start_line until the next heading at or above the given level."""
        out = []
        in_code = False
        for i in range(start_line, len(self.lines)):
            line = self.lines[i]
            if line.startswith('```'):
                in_code = not in_code
            match = None if in_code else HEADING.match(line)
            if match and len(match.group(1)) <= same_or_higher_level:
                break
            out.append((i + 1, line))
        return out


def parse_sections(doc):
    """Level-1 numbered sections: number -> {number, branch, title, line, subsections}."""
    sections = OrderedDict()
    for line_no, level, text in doc.headings:
        if level != 1:
            continue
        match = BRANCH_HEADING.match(text)
        if match:
            number, branch, title = match.groups()
            sections[number] = {'number': number, 'branch': branch, 'title': title.strip(), 'line': line_no}
            continue
        match = NUMBERED_HEADING.match(text)
        if match:
            number, title = match.groups()
            sections[number] = {'number': number, 'branch': None, 'title': title.strip(), 'line': line_no}
    for section in sections.values():
        body = doc.section_body(section['line'], 1)
        section['end'] = body[-1][0] if body else section['line']
        section['fr'] = OrderedDict()      # id -> occurrence
        section['rows'] = OrderedDict()    # id -> occurrence
        section['decisions'] = []          # [(D, gist, line)]
        current = ''
        for line_no, line in body:
            heading = HEADING.match(line)
            if heading:
                current = heading.group(2)
                continue
            row = TABLE_ROW.match(line)
            if row:
                row_id, qualifier, text = row.groups()
                occurrence = {
                    'id': row_id, 'line': line_no, 'section': section['number'],
                    'subsection': current, 'qualifier': (qualifier or '').strip(), 'text': text,
                }
                target = section['fr'] if row_id.startswith('FR-') else section['rows']
                target.setdefault(row_id, occurrence)
                continue
            if current == 'Decisions':
                bullet = DECISION_BULLET.match(line)
                if bullet:
                    section['decisions'].append((bullet.group(1), bullet.group(2).strip(), line_no))
    return sections


def parse_decisions_log(doc, log_section):
    """Section 16 entries: D-number -> {title, date_heading, line}."""
    decisions = OrderedDict()
    if log_section is None:
        return decisions
    for line_no, line in doc.section_body(log_section['line'], 1):
        match = DECISION_ENTRY.match(line)
        if not match:
            continue
        number, title = match.groups()
        decisions[number] = {
            'title': title.strip().rstrip('.'),
            'date_heading': doc.nearest_heading_of_level(line_no, 2),
            'line': line_no,
        }
    return OrderedDict(sorted(decisions.items(), key=lambda item: natural_key(item[0])))


def subsection_label(doc, line_no):
    """'15.1 Document-image sharing …' for a row inside section 15; '' elsewhere."""
    heading = doc.nearest_heading_of_level(line_no, 2)
    return heading if SUBSECTION_HEADING.match(heading) else ''


# --------------------------------------------------------------------------- foundation.yml (stdlib subset parser)

def parse_simple_yaml(text):
    """A small YAML subset: block mappings and sequences, flow [..] and {..}, scalars, comments."""
    lines = []
    for raw in text.split('\n'):
        stripped = _strip_comment(raw).rstrip()
        if stripped.strip():
            lines.append((len(stripped) - len(stripped.lstrip()), stripped.strip()))
    value, index = _parse_block(lines, 0, lines[0][0] if lines else 0)
    if index != len(lines):
        raise ValueError(f'unparsed YAML from line {index}')
    return value


def _strip_comment(line):
    quote = None
    for i, char in enumerate(line):
        if quote:
            if char == quote:
                quote = None
        elif char in ('"', "'"):
            quote = char
        elif char == '#' and (i == 0 or line[i - 1] in ' \t'):
            return line[:i]
    return line


def _parse_block(lines, index, indent):
    if index >= len(lines):
        return None, index
    if lines[index][1].startswith('- ') or lines[index][1] == '-':
        return _parse_sequence(lines, index, indent)
    return _parse_mapping(lines, index, indent)


def _parse_sequence(lines, index, indent):
    items = []
    while index < len(lines) and lines[index][0] == indent and (lines[index][1].startswith('- ') or lines[index][1] == '-'):
        content = lines[index][1][1:].strip()
        if not content:
            value, index = _parse_block(lines, index + 1, lines[index + 1][0]) if index + 1 < len(lines) else (None, index + 1)
            items.append(value)
            continue
        if re.match(r'^[^\[\]{}"\'#][^:]*:(\s|$)', content):
            child_indent = indent + 2
            lines[index] = (child_indent, content)
            value, index = _parse_mapping(lines, index, child_indent)
            items.append(value)
            continue
        items.append(_parse_scalar(content))
        index += 1
    return items, index


def _parse_mapping(lines, index, indent):
    mapping = OrderedDict()
    while index < len(lines) and lines[index][0] == indent:
        content = lines[index][1]
        if content.startswith('- ') or content == '-':
            break
        match = re.match(r'^("[^"]*"|\'[^\']*\'|[^:]+?):(?:\s+(.*))?$', content)
        if not match:
            raise ValueError(f'cannot parse mapping line: {content!r}')
        key = _parse_scalar(match.group(1))
        rest = (match.group(2) or '').strip()
        if rest:
            mapping[key] = _parse_scalar(rest)
            index += 1
        elif index + 1 < len(lines) and lines[index + 1][0] > indent:
            value, index = _parse_block(lines, index + 1, lines[index + 1][0])
            mapping[key] = value
        elif index + 1 < len(lines) and lines[index + 1][0] == indent and lines[index + 1][1].startswith('- '):
            value, index = _parse_sequence(lines, index + 1, indent)
            mapping[key] = value
        else:
            mapping[key] = None
            index += 1
    return mapping, index


def _parse_scalar(text):
    text = text.strip()
    if text.startswith('[') and text.endswith(']'):
        return [_parse_scalar(part) for part in _split_flow(text[1:-1]) if part.strip()]
    if text.startswith('{') and text.endswith('}'):
        result = OrderedDict()
        for part in _split_flow(text[1:-1]):
            if ':' in part:
                key, value = part.split(':', 1)
                result[_parse_scalar(key)] = _parse_scalar(value)
        return result
    if len(text) >= 2 and text[0] == text[-1] and text[0] in '"\'':
        return text[1:-1]
    if text in ('true', 'True', 'yes'):
        return True
    if text in ('false', 'False', 'no'):
        return False
    if text in ('null', '~', ''):
        return None
    if re.fullmatch(r'-?\d+', text):
        return int(text)
    return text


def _split_flow(text):
    parts, depth, quote, current = [], 0, None, ''
    for char in text:
        if quote:
            current += char
            if char == quote:
                quote = None
        elif char in '"\'':
            quote = char
            current += char
        elif char in '[{':
            depth += 1
            current += char
        elif char in ']}':
            depth -= 1
            current += char
        elif char == ',' and depth == 0:
            parts.append(current)
            current = ''
        else:
            current += char
    if current.strip():
        parts.append(current)
    return parts


FOUNDATION_FR_KEYS = ('fr', 'fr_id', 'fr_ids', 'requirements', 'functional_requirements', 'satisfies')
FOUNDATION_ROW_KEYS = ('rows', 'protocol_rows')
FOUNDATION_BRANCH_KEYS = ('kept_by', 'branch', 'branches')
FOUNDATION_NOTE_KEYS = ('note', 'title', 'summary', 'description', 'what')


def _as_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value if item is not None]
    return [part.strip() for part in re.split(r'[;,]\s*', str(value)) if part.strip()]


def load_foundation(path, known_prefixes):
    """Items from references/foundation.yml, or ([], status note) when absent or unreadable."""
    if not os.path.isfile(path):
        return [], 'references/foundation.yml not present; foundation items left empty'
    try:
        with open(path, encoding='utf-8') as handle:
            data = parse_simple_yaml(handle.read())
    except Exception as error:  # noqa: BLE001 - any parse failure is reported, never fatal
        return [], f'references/foundation.yml present but not readable by the stdlib subset parser ({error})'
    items = []

    def visit(node, inherited_id):
        if isinstance(node, dict):
            fr_key = next((key for key in FOUNDATION_FR_KEYS if key in node), None)
            if fr_key is not None or 'id' in node:
                item_id = str(node.get('id') or inherited_id or f'item-{len(items) + 1}')
                fr_ids = expand_fr(' '.join(_as_list(node.get(fr_key)))) if fr_key else []
                note = next((str(node[key]) for key in FOUNDATION_NOTE_KEYS if node.get(key)), '')
                rows = []
                for key in FOUNDATION_ROW_KEYS:
                    rows.extend(expand_rows(' '.join(_as_list(node.get(key))), known_prefixes))
                branches = []
                for key in FOUNDATION_BRANCH_KEYS:
                    branches.extend(_as_list(node.get(key)))
                items.append({'id': item_id, 'fr': fr_ids, 'rows': sorted_ids(rows),
                              'branches': branches, 'note': note})
            for key, value in node.items():
                if isinstance(value, (dict, list)):
                    visit(value, str(key))
        elif isinstance(node, list):
            for value in node:
                visit(value, inherited_id)

    visit(data, None)
    return items, f'{len(items)} foundation items read from references/foundation.yml'


# --------------------------------------------------------------------------- git

def git_branch_info(stack, base):
    """Per branch: tip, parent, commit list, directories touched; graceful when a branch is missing."""
    info = OrderedDict()
    previous = base if run_git('rev-parse', '--verify', '--quiet', base) else None
    for section in stack:
        branch = section['branch']
        tip = run_git('rev-parse', '--verify', '--quiet', '--short', branch)
        entry = {'branch': branch, 'section': section['number'], 'title': section['title'], 'tip': tip,
                 'parent': previous, 'commits': [], 'dirs': [], 'present': bool(tip), 'stacked': True}
        if tip and previous:
            entry['stacked'] = run_git('merge-base', '--is-ancestor', previous, branch, default=None) is not None
            log = run_git('log', '--no-merges', '--format=%h%x09%s', f'{previous}..{branch}', default='')
            for line in log.split('\n'):
                if line.strip():
                    sha, _, subject = line.partition('\t')
                    entry['commits'].append((sha, subject, expand_fr(subject)))
            names = run_git('diff', '--name-only', f'{previous}...{branch}', default='')
            dirs = set()
            for name in names.split('\n'):
                if name.strip():
                    dirs.add(name.split('/')[0] + ('/' if '/' in name else ''))
            entry['dirs'] = sorted(dirs)
        if tip:
            previous = branch
        info[branch] = entry
    return info


# --------------------------------------------------------------------------- model

class Model:
    """Everything the renderers need, parsed once."""

    def __init__(self, root, text=None):
        self.root = root
        self.doc = Document(root, DOC, text)
        self.sections = parse_sections(self.doc)
        self.stack = [s for s in self.sections.values() if s['branch']]
        self.base_section = self.sections.get(BASE_SECTION)
        self.decisions = parse_decisions_log(self.doc, self.sections.get(LOG_SECTION))
        # Owner of a row: the first branch section (stack order) that carries it; else section 15.
        self.fr_rows = OrderedDict()     # id -> [occurrences], owner first
        self.rows = OrderedDict()        # id -> [occurrences], owner first
        for section in self.stack + ([self.base_section] if self.base_section else []):
            for row_id, occurrence in section['fr'].items():
                self.fr_rows.setdefault(row_id, []).append(occurrence)
            for row_id, occurrence in section['rows'].items():
                self.rows.setdefault(row_id, []).append(occurrence)
        self.fr_rows = OrderedDict(sorted(self.fr_rows.items(), key=lambda item: natural_key(item[0])))
        self.rows = OrderedDict(sorted(self.rows.items(), key=lambda item: natural_key(item[0])))
        self.prefixes = tuple(sorted({row_prefix(r) for r in self.rows}))
        self.foundation, self.foundation_status = load_foundation(os.path.join(REFS_DIR, 'foundation.yml'), self.prefixes)
        self.section_decisions = {s['number']: sorted_ids(d for d, _, _ in s['decisions']) for s in self.sections.values()}

    # -- lookups

    def owner(self, occurrences):
        return self.sections[occurrences[0]['section']]

    def owner_label(self, occurrences):
        """'1' for a branch section; '15.3' for a section 15 subsection."""
        first = occurrences[0]
        if first['section'] == BASE_SECTION:
            label = subsection_label(self.doc, first['line'])
            return label.split(' ', 1)[0] if label else BASE_SECTION
        return first['section']

    def branch_label(self, occurrences):
        section = self.owner(occurrences)
        return f'`{section["branch"]}`' if section['branch'] else BASE_OWNER

    def also_in(self, occurrences):
        return [self.owner_label([o]) for o in occurrences[1:]]

    def cites(self, text):
        return expand_fr(text), expand_rows(text, self.prefixes), expand_decisions(text)

    def section_rows(self, number):
        return sorted_ids(self.sections[number]['rows'])

    def citing_sections(self, d_id):
        return [n for n, ids in self.section_decisions.items() if d_id in ids]

    def rows_citing(self, d_id, rows):
        hits = []
        for row_id, occurrences in rows.items():
            if any(d_id in expand_decisions(o['text']) for o in occurrences):
                hits.append(row_id)
        return hits

    def foundation_for_section(self, section):
        fr_set = set(section['fr'])
        hits = []
        for item in self.foundation:
            if (section['branch'] and section['branch'] in item['branches']) or \
               (not section['branch'] and BASE_BRANCH in item['branches']) or \
               (not item['branches'] and fr_set.intersection(item['fr'])):
                hits.append(item)
        return hits

    def foundation_for_fr(self, fr_id):
        return [item for item in self.foundation if fr_id in item['fr']]

    def section_of_branch(self, branch):
        return next((s for s in self.stack if s['branch'] == branch), None)

    def foundation_owner(self, item):
        for branch in item['branches']:
            section = self.section_of_branch(branch)
            if section:
                return f'section {section["number"]} (`{branch}`)'
            if branch == BASE_BRANCH:
                return f'section {BASE_SECTION} (`{branch}`)'
        return '—'


# --------------------------------------------------------------------------- rendering

def header(base_sha):
    return (f'<!-- generated by {SKILL_REL}/scripts/build_index.py from {DOC} and git at {base_sha}; '
            'do not edit by hand -->')


HEADER_SHA = re.compile(r'( and git at )[0-9a-f]+;')


def normalize(text):
    return HEADER_SHA.sub(r'\1SHA;', text)


def section_cell(model, occurrences):
    label = model.owner_label(occurrences)
    also = model.also_in(occurrences)
    return label + (f' (also {", ".join(also)})' if also else '')


def counts_line(model):
    base_fr = sum(1 for o in model.fr_rows.values() if o[0]['section'] == BASE_SECTION)
    base_rows = sum(1 for o in model.rows.values() if o[0]['section'] == BASE_SECTION)
    return (f'{len(model.fr_rows)} FR rows, {len(model.rows)} protocol rows ({len(model.prefixes)} prefixes), '
            f'{len(model.stack)} branch sections, {base_fr + base_rows} rows owned by section {BASE_SECTION}, '
            f'{len(model.decisions)} decisions')


def render_requirements_index(model, base_sha):
    counts = counts_line(model)
    out = [header(base_sha), '', '# Requirements index', '',
           f'Every identifier in `{DOC}`, where it is defined and which branch delivers it. Line numbers are those',
           'of the document at the base sha in the header. "Section" is the branch section (1 to 14) that owns the',
           f'row, or the section {BASE_SECTION} subsection for rows kept on the base or outside this repository; a row',
           'that appears again in another section (an amendment delivered there, or a pointer) lists it as "also".',
           '"Cites" lists the identifiers the row\'s own text names. Load the cited section for the text.', '',
           f'Counts: {counts}.', '']

    out += ['## Sections', '',
            '| Section | Branch | Title | Line | FR rows | Protocol rows | Decisions |', '|---|---|---|---|---|---|---|']
    for section in model.stack:
        out.append('| ' + ' | '.join([
            section['number'], f'`{section["branch"]}`', cell(section['title']), str(section['line']),
            compress(section['fr']), compress(section['rows']), compress(model.section_decisions[section['number']])]) + ' |')
    if model.base_section:
        section = model.base_section
        out.append('| ' + ' | '.join([
            section['number'], BASE_OWNER, cell(section['title']), str(section['line']),
            compress(section['fr']), compress(section['rows']), compress(model.section_decisions[section['number']])]) + ' |')

    out += ['', '## Functional requirement rows', '',
            '| ID | Section | Branch | Line | Cites |', '|---|---|---|---|---|']
    for fr_id, occurrences in model.fr_rows.items():
        first = occurrences[0]
        fr, rows, decisions = model.cites(first['text'])
        cites = join([*(f for f in fr if f != fr_id), *rows, *decisions])
        out.append('| ' + ' | '.join([
            f'`{fr_id}`', section_cell(model, occurrences), model.branch_label(occurrences),
            ', '.join(str(o['line']) for o in occurrences), cites]) + ' |')

    out += ['', '## Protocol rows', '',
            '| ID | Section | Branch | Line | Qualifier | Cites |', '|---|---|---|---|---|---|']
    for row_id, occurrences in model.rows.items():
        first = occurrences[0]
        fr, rows, decisions = model.cites(first['text'])
        cites = join([*fr, *(r for r in rows if r != row_id), *decisions])
        out.append('| ' + ' | '.join([
            f'`{row_id}`', section_cell(model, occurrences), model.branch_label(occurrences),
            ', '.join(str(o['line']) for o in occurrences), cell(first['qualifier'] or '—'), cites]) + ' |')

    out += ['', f'## Decisions (section {LOG_SECTION})', '', 'Cross-references are in `decisions.md`.', '',
            '| ID | Title | Dated subsection | Line | Sections citing |', '|---|---|---|---|---|']
    for d_id, decision in model.decisions.items():
        out.append(f'| `{d_id}` | {cell(decision["title"])} | {cell(decision["date_heading"])} | {decision["line"]} | '
                   f'{join(model.citing_sections(d_id))} |')
    out.append('')
    return '\n'.join(out), counts


def render_fr_matrix(model):
    out = ['| FR row | Section and branch | Protocol rows | Decisions |', '|---|---|---|---|']
    for fr_id, occurrences in model.fr_rows.items():
        owner = model.owner(occurrences)
        if owner['branch']:
            where = f'{section_cell(model, occurrences)} `{owner["branch"]}`'
        else:
            where = f'{section_cell(model, occurrences)} {BASE_OWNER}'
        out.append(f'| `{fr_id}` | {where} | {compress(model.section_rows(owner["number"]))} | '
                   f'{compress(model.section_decisions[owner["number"]])} |')
    return '\n'.join(out)


def render_prefix_matrix(model):
    out = ['| Prefix | Rows | Section and branch |', '|---|---|---|']
    groups = OrderedDict()
    for row_id, occurrences in model.rows.items():
        groups.setdefault(row_prefix(row_id), []).append((row_id, occurrences))
    for prefix, rows in groups.items():
        by_owner = OrderedDict()
        for row_id, occurrences in rows:
            by_owner.setdefault((model.owner_label(occurrences), model.branch_label(occurrences)), []).append(row_id)
        if len(by_owner) == 1:
            (label, branch), ids = next(iter(by_owner.items()))
            out.append(f'| {prefix} | {compress(ids)} ({len(ids)}) | section {label} {branch} |')
            continue
        parts = [f'{compress(ids)}: section {label} {branch}' for (label, branch), ids in by_owner.items()]
        out.append(f'| {prefix} | {len(rows)} rows | {"; ".join(parts)} |')
    return '\n'.join(out)


def render_base_matrix(model):
    out = [f'| Row | Section {BASE_SECTION} subsection | Decisions cited |', '|---|---|---|']
    base_rows = [(i, o) for i, o in list(model.fr_rows.items()) + list(model.rows.items())
                 if o[0]['section'] == BASE_SECTION]
    for row_id, occurrences in sorted(base_rows, key=lambda item: (natural_key(model.owner_label(item[1])), natural_key(item[0]))):
        first = occurrences[0]
        label = subsection_label(model.doc, first['line']) or model.base_section['title']
        out.append(f'| `{row_id}` | {cell(label)} | {join(expand_decisions(first["text"]))} |')
    return '\n'.join(out)


def render_foundation_matrix(model):
    out = ['| Foundation item | FR rows | Protocol rows | Kept by |', '|---|---|---|---|']
    for item in model.foundation:
        out.append(f'| `{item["id"]}` | {join(item["fr"])} | {join(item["rows"])} | {model.foundation_owner(item)} |')
    return '\n'.join(out)


def render_appendix_body(model):
    return '\n'.join([
        '**Functional requirement rows.** Section and branch that own the row; the protocol rows and the decisions '
        'listed are those of the owning section.', '',
        render_fr_matrix(model), '',
        '**Protocol rows by prefix.**', '',
        render_prefix_matrix(model), '',
        f'**Rows owned by section {BASE_SECTION}** (the base branch and work outside this repository).', '',
        render_base_matrix(model), '',
        '**Foundation items** (`' + SKILL_REL + '/references/foundation.yml`): pieces the foundation branch already '
        'satisfied, and the section that keeps them.', '',
        render_foundation_matrix(model),
    ])


def render_traceability(model, base_sha):
    out = [header(base_sha), '', '# Traceability matrix', '',
           f'FR row → section and branch → protocol rows → decisions, derived from `{DOC}`: a row belongs to the',
           'section whose table defines it (sections 1 to 14 in stack order; section 15 for the base branch and work',
           'outside this repository), and the section\'s Protocol rows table and Decisions list give the other two',
           'columns. Appendix A of the document carries the same matrix, written by the same generator.', '',
           '## Foundation items', '',
           '`references/foundation.yml` (written by hand from the review of the foundation branch, Appendix E of the',
           'document) is read when present. Shape: a list of mappings with `id`, `fr` (FR ids; `FR-X-1 to FR-X-4`',
           'ranges allowed), `rows` (protocol row ids), `section` (free text), `kept_by` (the branch that keeps the',
           'piece) and `note` (one line). An item is listed under a section when `kept_by` names its branch or, without',
           'one, when its FR ids intersect the section\'s FR rows. Parsing uses a small stdlib YAML subset: block and',
           'flow mappings and sequences, quoted and bare scalars, `#` comments.', '',
           f'Status: {model.foundation_status}.', '',
           '## By section, in stack order', '']
    for section in model.stack + ([model.base_section] if model.base_section else []):
        owner = f'`{section["branch"]}`' if section['branch'] else BASE_OWNER
        out += [f'### {section["number"]}. {owner} — {section["title"]}', '',
                f'- Line {section["line"]}',
                f'- FR rows: {compress(section["fr"])}',
                f'- Protocol rows: {compress(section["rows"])}',
                f'- Decisions: {compress(model.section_decisions[section["number"]])}']
        hits = model.foundation_for_section(section)
        if hits:
            out.append('- Foundation items:')
            for item in hits:
                out.append(f'  - `{item["id"]}`: {join(item["fr"])}' + (f' — {item["note"]}' if item['note'] else ''))
        else:
            out.append('- Foundation items: —')
        out.append('')
    out += ['## Functional requirement rows', '', render_fr_matrix(model), '',
            '## Protocol rows by prefix', '', render_prefix_matrix(model), '',
            f'## Rows owned by section {BASE_SECTION}', '',
            'Rows no branch section defines: kept on the base, delivered outside this repository, documented and not',
            'built, or process obligations. Check this list when a review asks "where is X implemented".', '',
            render_base_matrix(model), '']
    return '\n'.join(out)


def render_branches(model, info, base_sha):
    present = sum(1 for entry in info.values() if entry['present'])
    out = [header(base_sha), '', '# Branch stack', '',
           f'Stack order from the section headings of `{DOC}`; state from the local git repository ({present} of',
           f'{len(info)} branches present). Tips move whenever a lower branch changes (Appendix B: feature branch heads',
           'are not stable until fast-forwarded into the base); rerun the generator after a rebase. Commit counts are',
           'against the parent shown.', '',
           '| # | Branch | Section | Tip | Parent | Commits | Top-level paths touched (merge-base diff) |', '|---|---|---|---|---|---|---|']
    for position, entry in enumerate(info.values(), 1):
        if not entry['present']:
            out.append(f'| {position} | `{entry["branch"]}` | {entry["section"]} | branch not present locally | — | — | — |')
            continue
        parent = f'`{entry["parent"]}`' + ('' if entry['stacked'] else ' (not an ancestor: rebase needed)')
        out.append(f'| {position} | `{entry["branch"]}` | {entry["section"]} | `{entry["tip"]}` | {parent} | '
                   f'{len(entry["commits"])} | {join(f"`{d}`" for d in entry["dirs"])} |')
    out.append('')
    for position, entry in enumerate(info.values(), 1):
        out.append(f'## {position}. `{entry["branch"]}` (section {entry["section"]}: {cell(entry["title"])})')
        out.append('')
        if not entry['present']:
            out += ['Branch not present locally; fetch it to list its commits.', '']
            continue
        out.append(f'Tip `{entry["tip"]}`, {len(entry["commits"])} commits on `{entry["parent"]}`'
                   + ('.' if entry['stacked'] else '; the parent tip is not an ancestor, so this branch needs a rebase.'))
        out.append('')
        for sha, subject, fr_ids in entry['commits']:
            cites = f' (cites {", ".join(fr_ids)})' if fr_ids else ''
            out.append(f'- `{sha}` {cell(subject)}{cites}')
        out.append('')
    return '\n'.join(out)


def render_decisions(model, base_sha):
    out = [header(base_sha), '', '# Decisions', '',
           f'Section {LOG_SECTION} of `{DOC}` with the sections and rows that cite each decision. "Sections citing" are',
           'the branch sections whose Decisions list carries the D-number; "rows citing" are the FR and protocol rows',
           'whose text names it. The full entry (rationale and the rejected alternative) is at the line given.', '',
           '| ID | Title | Dated subsection | Line | Sections citing | FR rows citing | Protocol rows citing |',
           '|---|---|---|---|---|---|---|']
    for d_id, decision in model.decisions.items():
        out.append('| ' + ' | '.join([
            f'`{d_id}`', cell(decision['title']), cell(decision['date_heading']), str(decision['line']),
            join(model.citing_sections(d_id)), compress(model.rows_citing(d_id, model.fr_rows)),
            compress(model.rows_citing(d_id, model.rows))]) + ' |')
    out.append('')
    return '\n'.join(out)


# --------------------------------------------------------------------------- the document's Appendix A

def with_matrix(doc_text, body):
    """Document text with the marked Appendix A body replaced."""
    if BEGIN not in doc_text or END not in doc_text:
        sys.exit(f'{DOC} lacks the {BEGIN} / {END} marker pair in Appendix A')
    head, _, rest = doc_text.partition(BEGIN)
    _, _, tail = rest.partition(END)
    return f'{head}{BEGIN}\n{body}\n{END}{tail}'


# --------------------------------------------------------------------------- main

def compute_outputs(root, base_sha):
    """All outputs as {absolute path: text}. The document first, so line numbers reflect the regenerated appendix."""
    model = Model(root)
    outputs = OrderedDict()
    new_text = with_matrix(model.doc.text, render_appendix_body(model))
    outputs[model.doc.path] = new_text
    if new_text != model.doc.text:
        model = Model(root, new_text)
    info = git_branch_info(model.stack, BASE_BRANCH)
    index_text, counts = render_requirements_index(model, base_sha)
    outputs[os.path.join(REFS_DIR, 'requirements-index.md')] = index_text
    outputs[os.path.join(REFS_DIR, 'traceability.md')] = render_traceability(model, base_sha)
    outputs[os.path.join(REFS_DIR, 'branches.md')] = render_branches(model, info, base_sha)
    outputs[os.path.join(REFS_DIR, 'decisions.md')] = render_decisions(model, base_sha)
    present = sum(1 for entry in info.values() if entry['present'])
    summary = f'{counts}, {len(info)} branches ({present} present locally); {model.foundation_status}'
    return outputs, summary


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--check', action='store_true', help='recompute and compare; exit 1 on any difference')
    args = parser.parse_args()
    root = find_root()
    os.chdir(root)
    base_sha = run_git('rev-parse', '--short', BASE_BRANCH) or run_git('rev-parse', '--short', 'HEAD') or 'unknown'
    outputs, summary = compute_outputs(root, base_sha)
    stale = []
    for path, text in outputs.items():
        rel = os.path.relpath(path, root)
        if os.path.isfile(path):
            with open(path, encoding='utf-8') as handle:
                current = handle.read()
        else:
            current = ''
        if normalize(current) != normalize(text):
            diff = list(difflib.unified_diff(current.split('\n'), text.split('\n'), lineterm='', n=0))
            added = sum(1 for line in diff if line.startswith('+') and not line.startswith('+++'))
            removed = sum(1 for line in diff if line.startswith('-') and not line.startswith('---'))
            stale.append((rel, added, removed, 'missing' if not current else 'differs'))
    if args.check:
        if stale:
            print('stale generated output:')
            for rel, added, removed, state in stale:
                print(f'  {rel}: {state} (+{added} -{removed} lines)')
            print(f'run python3 {SKILL_REL}/scripts/build_index.py to regenerate')
            sys.exit(1)
        print(f'up to date: {summary}')
        return
    for path, text in outputs.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as handle:
            handle.write(text)
    written = ', '.join(rel for rel, *_ in stale) or 'nothing changed'
    print(f'generated: {summary}; rewrote: {written}')


if __name__ == '__main__':
    main()
