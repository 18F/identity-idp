interface TipListProps {
  title: string;
  items: string[];
  titleClassName?: string;
}

function TipList({ title, items = [], titleClassName }: TipListProps) {
  return (
    <div className="ads-copy ads-copy--muted">
      <p className={titleClassName}>
        <strong>{title}</strong>
      </p>
      <ul className="ads-list">
        {items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </div>
  );
}

export default TipList;
