interface TipListProps {
  title: string;
  items: string[];
}
function TipList({ title, items = [] }: TipListProps) {
  return (
    <>
      <p className="margin-bottom-0">{title}</p>
      <ul>
        {items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </>
  );
}

export default TipList;
