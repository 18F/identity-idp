import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import {
  FormStepComponentProps,
  FormStepsButton,
  FormStepsContext,
} from '@18f/identity-form-steps';
import { PageHeading } from '@18f/identity-components';
import { Cancel } from '@18f/identity-verify-flow';
import HybridDocCaptureWarning from './hybrid-doc-capture-warning';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import TipList from './tip-list';
import { DeviceContext, SelfieCaptureContext, UploadContext } from '../context';
import {ImageValue, DefaultSideProps} from './documents-and-selfie-step';

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