#!/usr/bin/env python3
"""Regenerate the delegated-access skill's indexes from the three documents under docs/ and git.

Outputs (all under .claude/skills/login-delegated-access/references/):
  requirements-index.md  every identifier -> document, section, line, plan feature, branch
  traceability.md        branch -> plan section -> FR rows -> companion rows -> foundation items
  branches.md            the stack as git sees it (tips, parents, commits, directories touched)
  decisions.md           D-numbers with the rows that cite them

and the generated body between the `<!-- traceability:begin -->` / `<!-- traceability:end -->`
markers of three appendices in the documents themselves (plan 8.1, FR Appendix E, companion
Appendix F). The appendices are created, with their markers, when missing.

Usage:
  build_index.py            regenerate everything, print a one-line summary
  build_index.py --check    recompute without writing; exit 1 with a diff summary if anything
                            on disk differs (the base sha in the header line is ignored)

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

PLAN = 'docs/delegated-access-implementation-plan.md'
FR = 'docs/delegated-access-functional-requirements.md'
COMPANION = 'docs/delegated-access-requirements.md'

BEGIN = '<!-- traceability:begin -->'
END = '<!-- traceability:end -->'

FR_ID = re.compile(r'\bFR-[A-Z]{2,5}-\d+\b')
FR_RANGE = re.compile(r'\b(FR-[A-Z]{2,5})-(\d+)\s+to\s+\1-(\d+)\b')
ROW_ID = re.compile(r'\b([A-Z]{2,5})-(\d+)([a-z]?)\b')
ROW_RANGE = re.compile(r'\b([A-Z]{2,5})-(\d+)(?:\.\.(\d+)|\s+to\s+\1-(\d+))\b')
IS_E_ROW = re.compile(r'^E\d+$')
E_ID = re.compile(r'(?<![A-Za-z])E(\d+)(?:\s*[–-]\s*E(\d+))?\b')
D_ID = re.compile(r'(?<![A-Za-z])D(\d+)(?:\s*[–-]\s*D(\d+))?\b')
SECTION_REF = re.compile(r'§\s?(\d+(?:\.\d+)?)(?:\s*[–-]\s*§?\s?(\d+(?:\.\d+)?))?')
FEATURE_HEADING = re.compile(r'^### (5\.\d+)\s+(.*?)\s*$')
HEADING = re.compile(r'^(#{1,4})\s+(.*?)\s*$')
TABLE_ROW_BOLD = re.compile(r'^\|\s*\*\*([A-Z]{2,5}(?:-[A-Z]{2,5})?-\d+[a-z]?)\*\*\s*(\([^)|]*\))?\s*\|')
TABLE_ROW_E = re.compile(r'^\|\s*(E\d+)\s*\|')
DECISION_LINE = re.compile(r'^\d+\.\s+\*\*(D\d+)\s+[—–-]+\s+(.*?)\*\*')
APPD_ITEM = re.compile(r'^(\d+)\.\s+(.*)$')
STACK_ROW = re.compile(r'^\|\s*(\d+)\s*\|\s*`([a-z0-9-]+)`\s*\|\s*(5\.\d+)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*$')
COMPANION_PREFIXES = ('ONB', 'CON', 'ACC', 'EXC', 'INT', 'REF', 'ATT', 'BIL', 'DISC', 'SAML',
                      'TPL', 'DOC', 'UINF', 'KEY')


# --------------------------------------------------------------------------- helpers

def run_git(*args, default=None):
    try:
        out = subprocess.run(['git', *args], capture_output=True, text=True, check=True)
        return out.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return default


def find_root():
    root = run_git('rev-parse', '--show-toplevel')
    if root and os.path.isfile(os.path.join(root, PLAN)):
        return root
    here = SKILL_DIR
    while here != os.path.dirname(here):
        if os.path.isfile(os.path.join(here, PLAN)):
            return here
        here = os.path.dirname(here)
    sys.exit('cannot find the repository root (docs/delegated-access-implementation-plan.md)')


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


def expand_rows(text):
    """Companion row identifiers (ONB-1, EXC-17..19, CON-1 to CON-5, E28–E32) in text."""
    text = FR_ID.sub(' ', text)
    text = re.sub(r'\bRFC\s*\d+\b', ' ', text)
    ids = []
    for prefix, lo, hi_dots, hi_to in ROW_RANGE.findall(text):
        if prefix not in COMPANION_PREFIXES:
            continue
        hi = hi_dots or hi_to
        ids.extend(f'{prefix}-{n}' for n in range(int(lo), int(hi) + 1))
    for prefix, num, suffix in ROW_ID.findall(text):
        if prefix in COMPANION_PREFIXES:
            ids.append(f'{prefix}-{num}{suffix}')
    for lo, hi in E_ID.findall(text):
        if hi:
            ids.extend(f'E{n}' for n in range(int(lo), int(hi) + 1))
        else:
            ids.append(f'E{lo}')
    return sorted_ids(ids)


def expand_decisions(text):
    ids = []
    for lo, hi in D_ID.findall(text):
        if hi:
            ids.extend(f'D{n}' for n in range(int(lo), int(hi) + 1))
        else:
            ids.append(f'D{lo}')
    return sorted_ids(ids)


def section_refs(text):
    refs = []
    for lo, hi in SECTION_REF.findall(text):
        refs.append(f'§{lo}' + (f'–§{hi}' if hi else ''))
    for appendix in re.findall(r'Appendix [A-F]\b', text):
        refs.append(appendix)
    return list(OrderedDict.fromkeys(refs))


def join(ids, empty='—'):
    ids = list(ids)
    return ', '.join(ids) if ids else empty


def compress(ids, empty='—'):
    """Identifier list with consecutive numbers collapsed: FR-ONB-1..9, CON-1..19, E53..57."""
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


# --------------------------------------------------------------------------- document model

class Document:
    def __init__(self, root, rel, text=None):
        self.rel = rel
        self.path = os.path.join(root, rel)
        if text is None:
            with open(self.path, encoding='utf-8') as handle:
                text = handle.read()
        self.text = text
        # Generated matrix bodies are blanked (line count preserved) so the parser never reads its own output.
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

    def heading_at(self, line_no, min_level=1):
        best = None
        for number, level, text in self.headings:
            if number > line_no:
                break
            if level >= min_level:
                best = text
        return best or ''

    def nearest_heading_of_level(self, line_no, level):
        best = None
        for number, lvl, text in self.headings:
            if number > line_no:
                break
            if lvl == level:
                best = text
        return best or ''

    def section_body(self, start_line, same_or_higher_level):
        """Lines (1-based numbers and text) from start_line until the next heading of the given level or higher."""
        out = []
        for i in range(start_line, len(self.lines)):
            line = self.lines[i]
            match = HEADING.match(line)
            if match and len(match.group(1)) <= same_or_higher_level:
                break
            out.append((i + 1, line))
        return out


def section_number(heading):
    match = re.match(r'^(Appendix [A-F])\b', heading)
    if match:
        return match.group(1)
    match = re.match(r'^((?:\d+|[A-Z])(?:\.\d+)*)\.?\s', heading)
    return match.group(1) if match else heading.strip()


# --------------------------------------------------------------------------- parsing

def parse_rows(doc, want_e_rows=False):
    """Requirement rows in a document: id -> list of {line, section, qualifier}."""
    rows = defaultdict(list)
    for i, line in enumerate(doc.lines, 1):
        match = TABLE_ROW_BOLD.match(line)
        if match:
            rows[match.group(1)].append({
                'line': i,
                'section': doc.heading_at(i),
                'qualifier': (match.group(2) or '').strip(),
                'text': line,
            })
            continue
        if want_e_rows:
            match = TABLE_ROW_E.match(line)
            if match:
                rows[match.group(1)].append({
                    'line': i, 'section': doc.heading_at(i), 'qualifier': '', 'text': line,
                })
    return rows


def parse_features(plan):
    """Plan 5.x features: number -> {title, line, branch, fr, rows, sections, decisions, requirements_text}."""
    features = OrderedDict()
    for line_no, level, text in plan.headings:
        match = FEATURE_HEADING.match(f'### {text}') if level == 3 else None
        if not match:
            continue
        number, title = match.groups()
        body = plan.section_body(line_no, 3)
        feature = {
            'number': number, 'title': title, 'line': line_no, 'branch': None,
            'fr': [], 'rows': [], 'sections': [], 'decisions': [], 'requirements_text': '',
        }
        for _, body_line in body:
            worktree = re.search(r'\*\*Worktree\*\*\s*`([a-z0-9-]+)`', body_line)
            if worktree and not feature['branch']:
                feature['branch'] = worktree.group(1)
            req = re.search(r'\*\*Requirements[^*]*\*\*\s*(.*?)(?=\*\*Decisions|\*\*Companion repository|$)', body_line)
            if req:
                requirements_text = req.group(1).strip()
                feature['requirements_text'] = requirements_text
                feature['fr'] = expand_fr(requirements_text)
                feature['rows'] = expand_rows(requirements_text)
                feature['sections'] = section_refs(requirements_text)
            decisions = re.search(r'\*\*Decisions:\*\*\s*(.*?)(?:\.\s|$)', body_line)
            if decisions:
                feature['decisions'] = sorted_ids(feature['decisions'] + expand_decisions(decisions.group(1)))
        features[number] = feature
    return features


def parse_stack(plan):
    """Plan section 8 table: ordered list of {position, branch, feature, fr_text, rows_text}."""
    stack = []
    for line in plan.lines:
        match = STACK_ROW.match(line)
        if match:
            position, branch, feature, fr_text, rows_text = match.groups()
            stack.append({'position': int(position), 'branch': branch, 'feature': feature,
                          'fr_text': fr_text, 'rows_text': rows_text})
    stack.sort(key=lambda row: row['position'])
    seen = set()
    return [row for row in stack if not (row['branch'] in seen or seen.add(row['branch']))]


def parse_decisions(plan):
    """Plan section 9 decisions: D-number -> {title, date_heading, line, fr, rows}."""
    decisions = OrderedDict()
    start = next((n for n, lvl, text in plan.headings if lvl == 2 and text.startswith('9.')), None)
    if start is None:
        return decisions
    for line_no, line in plan.section_body(start, 2):
        match = DECISION_LINE.match(line)
        if not match:
            continue
        number, title = match.groups()
        decisions[number] = {
            'title': title.strip().rstrip('.'),
            'date_heading': plan.nearest_heading_of_level(line_no, 3),
            'line': line_no,
            'fr': expand_fr(line),
            'rows': expand_rows(line),
        }
    return OrderedDict(sorted(decisions.items(), key=lambda item: natural_key(item[0])))


def parse_appendix_d(fr):
    """FR doc Appendix D numbered items: item number -> {line, date_heading, fr, decisions}."""
    items = OrderedDict()
    start = next((n for n, lvl, text in fr.headings if lvl == 2 and text.startswith('Appendix D')), None)
    if start is None:
        return items
    for line_no, line in fr.section_body(start, 2):
        match = APPD_ITEM.match(line)
        if match:
            items[int(match.group(1))] = {
                'line': line_no,
                'date_heading': fr.nearest_heading_of_level(line_no, 3),
                'fr': expand_fr(line),
                'decisions': expand_decisions(line),
                'title': re.sub(r'\*\*', '', match.group(2))[:90],
            }
    return items


def parse_appendix_b(fr):
    """FR doc Appendix B: FR section number -> companion sections text."""
    mapping = {}
    start = next((n for n, lvl, text in fr.headings if lvl == 2 and text.startswith('Appendix B')), None)
    if start is None:
        return mapping
    for _, line in fr.section_body(start, 2):
        match = re.match(r'^\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*$', line)
        if not match or match.group(1) in ('This document', '---'):
            continue
        mapping[section_number(match.group(1) + ' ')] = match.group(2)
    return mapping


def parse_implemented(fr):
    """FR doc 'Implemented <date> (feature 5.x ...)' paragraphs: FR id -> list of (date, feature)."""
    implemented = defaultdict(list)
    for line in fr.lines:
        match = re.match(r'^\*\*Implemented (\d{4}-\d{2}-\d{2}) \(feature (5\.\d+)[^)]*\):\*\*\s*(.*)$', line)
        if match:
            date, feature, rest = match.groups()
            for fr_id in expand_fr(rest):
                implemented[fr_id].append((date, feature))
    return implemented


def fr_section_of(fr, line_no):
    return section_number(fr.nearest_heading_of_level(line_no, 2) + ' ')


def section_label(doc, line_no):
    """'3. Partner onboarding › Functional requirements' style label for a row."""
    major = doc.nearest_heading_of_level(line_no, 2)
    minor = doc.heading_at(line_no)
    return major if minor == major or not minor else f'{major} › {minor}'


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
            # inline mapping start: treat the rest as a mapping whose first line is this content
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
FOUNDATION_ROW_KEYS = ('companion', 'companion_rows', 'rows')
FOUNDATION_BRANCH_KEYS = ('kept_by', 'branch', 'branches')
FOUNDATION_NOTE_KEYS = ('note', 'title', 'summary', 'description', 'what')


def _as_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value if item is not None]
    return [part.strip() for part in re.split(r'[;,]\s*', str(value)) if part.strip()]


def load_foundation(path):
    """Items from references/foundation.yml, or ([], status note) when absent or unreadable."""
    if not os.path.isfile(path):
        return [], 'references/foundation.yml not present; foundation column left empty'
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
                    rows.extend(expand_rows(' '.join(_as_list(node.get(key)))))
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
    for row in stack:
        branch = row['branch']
        tip = run_git('rev-parse', '--verify', '--quiet', '--short', branch)
        entry = {'branch': branch, 'feature': row['feature'], 'tip': tip, 'parent': previous,
                 'commits': [], 'dirs': [], 'present': bool(tip), 'stacked': True}
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


# --------------------------------------------------------------------------- rendering

def header(base_sha):
    return (f'<!-- generated by {SKILL_REL}/scripts/build_index.py from docs/ and git at {base_sha}; '
            'do not edit by hand -->')


HEADER_SHA = re.compile(r'(from docs/ and git at )[0-9a-f]+;')


def normalize(text):
    return HEADER_SHA.sub(r'\1SHA;', text)


class Model:
    """Everything the renderers need, parsed once."""

    def __init__(self, root, texts=None):
        """texts: optional {relative doc path: text} overriding what is on disk."""
        self.root = root
        texts = texts or {}
        self.plan = Document(root, PLAN, texts.get(PLAN))
        self.fr = Document(root, FR, texts.get(FR))
        self.companion = Document(root, COMPANION, texts.get(COMPANION))
        self.fr_rows = parse_rows(self.fr)
        self.companion_rows = parse_rows(self.companion, want_e_rows=True)
        self.plan_rows = parse_rows(self.plan)  # the plan has no requirement tables of its own, but tolerate them
        self.features = parse_features(self.plan)
        self.stack = parse_stack(self.plan)
        self.decisions = parse_decisions(self.plan)
        self.appendix_d = parse_appendix_d(self.fr)
        self.appendix_b = parse_appendix_b(self.fr)
        self.implemented = parse_implemented(self.fr)
        self.foundation, self.foundation_status = load_foundation(os.path.join(REFS_DIR, 'foundation.yml'))
        self.feature_branch = {row['feature']: row['branch'] for row in self.stack}
        for feature in self.features.values():
            if feature['number'] not in self.feature_branch and feature['branch']:
                self.feature_branch[feature['number']] = feature['branch']
        self.fr_features = defaultdict(list)
        self.row_features = defaultdict(list)
        for number, feature in self.features.items():
            for fr_id in feature['fr']:
                self.fr_features[fr_id].append(number)
            for row_id in feature['rows']:
                self.row_features[row_id].append(number)
        self.e_rows = sorted_ids(r for r in self.companion_rows if IS_E_ROW.match(r))
        self.plain_rows = sorted_ids(r for r in self.companion_rows if not IS_E_ROW.match(r))

    def branches_for_features(self, numbers):
        return list(OrderedDict.fromkeys(self.feature_branch[n] for n in numbers if n in self.feature_branch))

    def companion_rows_for_fr(self, fr_id):
        rows = []
        for number in self.fr_features.get(fr_id, []):
            rows.extend(r for r in self.features[number]['rows'] if not IS_E_ROW.match(r))
        return sorted_ids(rows)

    def fr_rows_for_row(self, row_id):
        ids = []
        for number in self.row_features.get(row_id, []):
            ids.extend(self.features[number]['fr'])
        return sorted_ids(ids)

    def foundation_for_branch(self, branch, fr_ids):
        hits = []
        fr_set = set(fr_ids)
        for item in self.foundation:
            if branch in item['branches'] or (not item['branches'] and fr_set.intersection(item['fr'])):
                hits.append(item)
        return hits

    def foundation_for_fr(self, fr_id):
        return [item for item in self.foundation if fr_id in item['fr']]

    def stack_for_branch(self, branch):
        return next((row for row in self.stack if row['branch'] == branch), None)

    def feature_title(self, number):
        return self.features[number]['title'] if number in self.features else ''

    def citing_appendix_d(self, d_id):
        return [str(n) for n, item in self.appendix_d.items() if d_id in item['decisions']]

    def citing_rows(self, d_id):
        hits = []
        for row_id, occurrences in self.companion_rows.items():
            for occurrence in occurrences:
                if re.search(rf'(?<![A-Za-z]){d_id}\b', occurrence['text']):
                    hits.append(f'{row_id} (line {occurrence["line"]})')
        return hits

    def citing_features(self, d_id):
        return [n for n, feature in self.features.items() if d_id in feature['decisions']]


def render_requirements_index(model, base_sha):
    out = [header(base_sha), '', '# Requirements index', '',
           'Every identifier in the three delegated-access documents, where it is defined and what implements it.',
           'Line numbers are those of the documents at the base sha in the header. "Plan feature" and "Branch" come',
           'from each plan 5.x "**Requirements**" line (ranges expanded) and the plan section 8 table; the',
           '"Companion rows" of an FR row are the rows the same plan feature cites (feature-level, not row-level),',
           'and "Companion sections" come from the FR document\'s Appendix B. "Implemented" comes from the FR',
           'document\'s "**Implemented <date> (feature 5.x …)**" paragraphs. Load the cited section for the text.',
           '']
    counts = (f'{len(model.fr_rows)} FR rows, {len(model.plain_rows)} companion rows, {len(model.e_rows)} Appendix E rows, '
              f'{len(model.features)} plan features, {len(model.decisions)} decisions, {len(model.appendix_d)} Appendix D items')
    out += [f'Counts: {counts}.', '']

    out += ['## Functional requirements (`docs/delegated-access-functional-requirements.md`)', '',
            '| ID | Section | Line | Plan feature | Branch | Companion rows (via feature) | Companion sections (Appendix B) | Implemented |',
            '|---|---|---|---|---|---|---|---|']
    for fr_id in sorted_ids(model.fr_rows):
        occurrences = model.fr_rows[fr_id]
        first = occurrences[0]
        features = model.fr_features.get(fr_id, [])
        section_no = fr_section_of(model.fr, first['line'])
        implemented = '; '.join(f'{date} ({feature})' for date, feature in model.implemented.get(fr_id, []))
        lines = ', '.join(str(o['line']) for o in occurrences)
        out.append('| ' + ' | '.join([
            f'`{fr_id}`', cell(section_label(model.fr, first['line'])), lines, join(features), join(f'`{b}`' for b in model.branches_for_features(features)),
            compress(model.companion_rows_for_fr(fr_id)), cell(model.appendix_b.get(section_no, '—')), implemented or '—']) + ' |')

    out += ['', '## Companion rows (`docs/delegated-access-requirements.md`)', '',
            'A row listed more than once has an original and one or more amendment rows; the qualifier says which.', '',
            '| ID | Section | Line | Qualifier | Plan feature | Branch | FR rows (via feature) |',
            '|---|---|---|---|---|---|---|']
    for row_id in model.plain_rows:
        for occurrence in model.companion_rows[row_id]:
            features = model.row_features.get(row_id, [])
            out.append('| ' + ' | '.join([
                f'`{row_id}`', cell(section_label(model.companion, occurrence['line'])), str(occurrence['line']), cell(occurrence['qualifier'] or '—'),
                join(features), join(f'`{b}`' for b in model.branches_for_features(features)),
                compress(model.fr_rows_for_row(row_id))]) + ' |')

    out += ['', '## Companion Appendix E rows (protocol decisions)', '',
            '| ID | Line | Decisions cited | Plan features citing the row |', '|---|---|---|---|']
    for row_id in model.e_rows:
        occurrence = model.companion_rows[row_id][0]
        cited = expand_decisions(occurrence['text'])
        out.append(f'| `{row_id}` | {occurrence["line"]} | {join(cited)} | {join(model.row_features.get(row_id, []))} |')

    out += ['', '## Plan features (`docs/delegated-access-implementation-plan.md` section 5)', '',
            '| Feature | Title | Line | Branch | FR rows | Companion rows | Companion sections | Decisions |',
            '|---|---|---|---|---|---|---|---|']
    for number, feature in model.features.items():
        branch = model.feature_branch.get(number)
        out.append('| ' + ' | '.join([
            number, cell(feature['title']), str(feature['line']), f'`{branch}`' if branch else '—',
            compress(feature['fr']), compress(feature['rows']), join(feature['sections']), compress(feature['decisions'])]) + ' |')

    out += ['', '## Decisions (plan section 9)', '', 'Full cross-references are in `decisions.md`.', '',
            '| ID | Title | Date subsection | Line |', '|---|---|---|---|']
    for d_id, decision in model.decisions.items():
        out.append(f'| `{d_id}` | {cell(decision["title"])} | {cell(decision["date_heading"])} | {decision["line"]} |')

    out += ['', '## FR document Appendix D items', '',
            'The items are numbered in their own sequence; most do not carry a plan D-number. The FR rows each item',
            'cites give the link back to the plan decision with the same rows (see `decisions.md`).', '',
            '| Item | Date subsection | Line | FR rows cited | Plan decisions cited |', '|---|---|---|---|---|']
    for number, item in model.appendix_d.items():
        out.append(f'| {number} | {cell(item["date_heading"])} | {item["line"]} | {join(item["fr"])} | {join(item["decisions"])} |')
    out.append('')
    return '\n'.join(out), counts


def render_traceability(model, base_sha):
    out = [header(base_sha), '', '# Traceability matrix', '',
           'Branch → plan section → FR rows → companion rows → foundation items, in stack order (plan section 8).',
           'FR and companion rows come from each feature\'s "**Requirements**" line; the three documents carry the',
           'same matrix in plan 8.1, FR Appendix E and companion Appendix F, written by the same generator.', '',
           '## Foundation items', '',
           '`references/foundation.yml` (written by hand from the sbx-taigrr review) is read when present. Shape: a',
           'list (at the top level or under any key) of mappings with `id`, `fr` (FR ids; `FR-X-1 to FR-X-4` ranges',
           'allowed), `companion` (row ids), `plan` (section reference, free text), `kept_by` (the branch that keeps',
           'the piece; `branch` is accepted too) and `note` (one line). Example:',
           '`- {id: act_claim, fr: [FR-VER-3], companion: [INT-4, E12], kept_by: delegated-access-introspection, note: …}`.',
           'An item is listed under a branch when `kept_by` names it or, without one, when its FR ids intersect the',
           'branch\'s FR rows. Parsing uses a small stdlib YAML subset: block and flow mappings and sequences, quoted',
           'and bare scalars, `#` comments.', '',
           f'Status: {model.foundation_status}.', '']
    out += ['## By branch', '']
    all_fr, all_rows = set(), set()
    for row in model.stack:
        number = row['feature']
        feature = model.features.get(number)
        fr_ids = feature['fr'] if feature else []
        rows = feature['rows'] if feature else []
        all_fr.update(fr_ids)
        all_rows.update(rows)
        out += [f'### {row["position"]}. `{row["branch"]}` — plan {number} {model.feature_title(number)}', '',
                f'- Plan: section {number}' + (f' (line {feature["line"]})' if feature else ' (no 5.x section found)'),
                f'- FR rows: {compress(fr_ids)}',
                f'- Companion rows: {compress(r for r in rows if not IS_E_ROW.match(r))}',
                f'- Appendix E rows: {compress(r for r in rows if IS_E_ROW.match(r))}',
                f'- Companion sections: {join(feature["sections"]) if feature else "—"}',
                f'- Decisions: {join(feature["decisions"]) if feature else "—"}',
                f'- Section 8 table: FR "{row["fr_text"]}"; companion "{row["rows_text"]}"']
        hits = model.foundation_for_branch(row['branch'], fr_ids)
        if hits:
            out.append('- Foundation items:')
            for item in hits:
                out.append(f'  - `{item["id"]}`: {join(item["fr"])}' + (f' — {item["note"]}' if item['note'] else ''))
        else:
            out.append('- Foundation items: —')
        out.append('')
    unmapped_fr = [fr_id for fr_id in sorted_ids(model.fr_rows) if fr_id not in all_fr]
    unmapped_rows = [row_id for row_id in model.plain_rows if row_id not in all_rows]
    out += ['## Not mapped to a branch', '',
            'Rows no plan 5.x feature cites. Expected for the Department of State use case (FR-DOS, plan 5.12, kept on',
            'the base), the alternative pattern (FR-TPL, TPL rows, plan 5.13), FR-FIT, and rows added by amendments',
            'that the feature line does not enumerate. Check this list when a review asks "where is X implemented".', '',
            f'- FR rows: {compress(unmapped_fr)}', f'- Companion rows: {compress(unmapped_rows)}', '']
    return '\n'.join(out)


def render_branches(model, info, base_sha):
    present = sum(1 for entry in info.values() if entry['present'])
    out = [header(base_sha), '', '# Branch stack', '',
           f'Stack order from plan section 8; state from the local git repository ({present} of {len(info)} branches present).',
           'Tips move whenever a lower branch changes (plan section 8, "feature branch heads are not stable"); rerun the',
           'generator after a rebase. Commit counts are against the parent shown.', '',
           '| # | Branch | Plan | Tip | Parent | Commits | Top-level paths touched (merge-base diff) |', '|---|---|---|---|---|---|---|']
    for position, entry in enumerate(info.values(), 1):
        if not entry['present']:
            out.append(f'| {position} | `{entry["branch"]}` | {entry["feature"]} | branch not present locally | — | — | — |')
            continue
        parent = f'`{entry["parent"]}`' + ('' if entry['stacked'] else ' (not an ancestor: rebase needed)')
        out.append(f'| {position} | `{entry["branch"]}` | {entry["feature"]} | `{entry["tip"]}` | {parent} | '
                   f'{len(entry["commits"])} | {join(f"`{d}`" for d in entry["dirs"])} |')
    out.append('')
    for position, entry in enumerate(info.values(), 1):
        out.append(f'## {position}. `{entry["branch"]}` (plan {entry["feature"]} {model.feature_title(entry["feature"])})')
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
           'Plan section 9 decisions with the rows that cite them. "FR Appendix D items" and "Companion rows" list only',
           'explicit `Dnn` citations; FR Appendix D items are numbered in their own sequence, so an item without a',
           'D-number is found through the FR rows it shares with the decision (`requirements-index.md`).', '',
           '| ID | Title | Date subsection | Plan line | FR rows cited | Companion rows cited | Plan features | FR Appendix D items citing | Companion rows citing |',
           '|---|---|---|---|---|---|---|---|---|']
    for d_id, decision in model.decisions.items():
        out.append('| ' + ' | '.join([
            f'`{d_id}`', cell(decision['title']), cell(decision['date_heading']), str(decision['line']),
            join(decision['fr']), join(decision['rows']), join(model.citing_features(d_id)),
            join(model.citing_appendix_d(d_id)), join(model.citing_rows(d_id))]) + ' |')
    out.append('')
    return '\n'.join(out)


def render_plan_matrix(model):
    out = ['| # | Branch | Plan | FR rows | Companion rows | Foundation items |', '|---|---|---|---|---|---|']
    for row in model.stack:
        feature = model.features.get(row['feature'])
        fr_ids = feature['fr'] if feature else []
        rows = feature['rows'] if feature else []
        hits = model.foundation_for_branch(row['branch'], fr_ids)
        out.append(f'| {row["position"]} | `{row["branch"]}` | {row["feature"]} | {compress(fr_ids)} | {compress(rows)} | '
                   f'{join(f"`{h["id"]}`" for h in hits)} |')
    return '\n'.join(out)


def render_fr_matrix(model):
    out = ['| FR row | Section | Companion rows (via plan feature) | Plan section | Branch | Foundation items |',
           '|---|---|---|---|---|---|']
    for fr_id in sorted_ids(model.fr_rows):
        features = model.fr_features.get(fr_id, [])
        section_no = fr_section_of(model.fr, model.fr_rows[fr_id][0]['line'])
        hits = model.foundation_for_fr(fr_id)
        out.append(f'| `{fr_id}` | {section_no} | {compress(model.companion_rows_for_fr(fr_id))} | {join(features)} | '
                   f'{join(f"`{b}`" for b in model.branches_for_features(features))} | {join(f"`{h["id"]}`" for h in hits)} |')
    return '\n'.join(out)


def render_companion_matrix(model):
    out = ['| Row group | Rows | Sections | FR rows (via plan feature) | Plan section | Branch |', '|---|---|---|---|---|---|']
    groups = OrderedDict()
    for row_id in model.plain_rows:
        groups.setdefault(re.sub(r'-\d+[a-z]?$', '', row_id), []).append(row_id)
    for prefix, rows in groups.items():
        features = sorted_ids(n for r in rows for n in model.row_features.get(r, []))
        fr_ids = sorted_ids(f for r in rows for f in model.fr_rows_for_row(r))
        sections = sorted_ids(
            '§' + section_number(o['section'] + ' ') for r in rows for o in model.companion_rows[r])
        out.append(f'| {prefix} | {compress(rows)} ({len(rows)}) | {join(sections)} | {compress(fr_ids)} | {join(features)} | '
                   f'{join(f"`{b}`" for b in model.branches_for_features(features))} |')
    e_features = sorted_ids(n for r in model.e_rows for n in model.row_features.get(r, []))
    out.append(f'| E | {compress(model.e_rows)} ({len(model.e_rows)}) | §Appendix E | — | {join(e_features)} | '
               f'{join(f"`{b}`" for b in model.branches_for_features(e_features))} |')
    return '\n'.join(out)


# --------------------------------------------------------------------------- document appendices

APPENDICES = {
    PLAN: {
        'heading': '### 8.1 Traceability matrix',
        'intro': ('Generated by `' + SKILL_REL + '/scripts/build_index.py` from the 5.x "**Requirements**" lines, the '
                  'section 8 table and the skill\'s `references/foundation.yml`; the FR document\'s Appendix E and the '
                  'companion\'s Appendix F carry the same matrix from their own side. Only the body between the markers '
                  'is generated.'),
        'insert_before': re.compile(r'^## 9\. '),
        'render': render_plan_matrix,
    },
    FR: {
        'heading': '## Appendix E — Traceability matrix',
        'intro': ('Generated by `' + SKILL_REL + '/scripts/build_index.py` from the implementation plan\'s 5.x '
                  '"**Requirements**" lines and section 8 table (see plan 8.1 and companion Appendix F). Only the body '
                  'between the markers is generated.'),
        'insert_before': None,
        'render': render_fr_matrix,
    },
    COMPANION: {
        'heading': '## Appendix F — Traceability matrix',
        'intro': ('Generated by `' + SKILL_REL + '/scripts/build_index.py` from the implementation plan\'s 5.x '
                  '"**Requirements**" lines and section 8 table (see plan 8.1 and FR Appendix E). Only the body between '
                  'the markers is generated.'),
        'insert_before': None,
        'render': render_companion_matrix,
    },
}


def with_matrix(doc_text, spec, body):
    """Document text with the marked body replaced (or the appendix created) for one document."""
    if BEGIN in doc_text and END in doc_text:
        head, _, rest = doc_text.partition(BEGIN)
        _, _, tail = rest.partition(END)
        return f'{head}{BEGIN}\n{body}\n{END}{tail}'
    block = f'{spec["heading"]}\n\n{spec["intro"]}\n\n{BEGIN}\n{body}\n{END}\n'
    lines = doc_text.split('\n')
    if spec['insert_before'] is not None:
        for index, line in enumerate(lines):
            if spec['insert_before'].match(line):
                insert_at = index
                while insert_at > 0 and lines[insert_at - 1].strip() in ('', '---'):
                    insert_at -= 1
                return '\n'.join(lines[:insert_at] + [''] + block.split('\n') + ['---', ''] + lines[index:])
    text = doc_text.rstrip('\n')
    return f'{text}\n\n---\n\n{block}'


# --------------------------------------------------------------------------- main

def compute_outputs(root, base_sha):
    """All outputs as {absolute path: text}. Documents first, so line numbers reflect the regenerated appendices."""
    model = Model(root)
    outputs = OrderedDict()
    docs_changed = False
    for rel, spec in APPENDICES.items():
        doc = getattr(model, {PLAN: 'plan', FR: 'fr', COMPANION: 'companion'}[rel])
        new_text = with_matrix(doc.text, spec, spec['render'](model))
        outputs[doc.path] = new_text
        docs_changed = docs_changed or new_text != doc.text
    if docs_changed:
        # Re-parse against the regenerated appendices so recorded line numbers match the written documents.
        model = Model(root, {rel: outputs[os.path.join(root, rel)] for rel in APPENDICES})
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
