interface TipListProps {
  title: string;
  items: string[];
  titleClassName?: string;
}
function TipList({ title, items = [], titleClassName }: TipListProps) {
  return (
    <>
      <p className={titleClassName}>{title}</p>
      <ul>
        {items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </>
  );
}

export default TipList;
