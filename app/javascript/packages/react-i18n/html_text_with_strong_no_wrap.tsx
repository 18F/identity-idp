import formatHTML from './format-html';

function HtmlTextWithStrongNoWrap({ text }: { text: string }) {
  return (
    <>
      {formatHTML(text, {
        strong: ({ children }) => <strong className="text-no-wrap">{children}</strong>,
      })}
    </>
  );
}

export default HtmlTextWithStrongNoWrap;
