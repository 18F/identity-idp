import { useI18n } from '@18f/identity-react-i18n';

interface TipListProps {
  title: string;
  items: string[];
  translationNeeded?: boolean;
}
function TipList({ translationNeeded = false, title, items = [] }: TipListProps) {
  const { t } = useI18n();
  return (
    <>
      <p className="margin-bottom-0">{translationNeeded ? t(title) : title}</p>
      <ul>
        {items.map((item, idx) => (
          <li key={`tip-item-${idx}`}>{translationNeeded ? t(item) : item}</li>
        ))}
      </ul>
    </>
  );
}

export default TipList;
