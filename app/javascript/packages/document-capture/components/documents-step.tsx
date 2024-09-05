import DocumentSideAcuantCapture from './document-side-acuant-capture';
import { ImageValue, DefaultSideProps } from '../interface/documents-image-selfie-value';

export default function DocumentsStep({
  defaultSideProps,
  value,
}: {
  defaultSideProps: DefaultSideProps;
  value: Record<string, ImageValue>;
}) {
  type DocumentSide = 'front' | 'back';
  const documentsSides: DocumentSide[] = ['front', 'back'];
  return (
    <>
      {documentsSides.map((side) => (
        <DocumentSideAcuantCapture
          {...defaultSideProps}
          key={side}
          side={side}
          value={value[side]}
        />
      ))}
    </>
  );
}
