import { FormStepComponentProps } from '@18f/identity-form-steps';

export type ImageValue = Blob | string | null | undefined;
export interface DocumentsAndSelfieStepValue {
  front: ImageValue;
  back: ImageValue;
  passport: ImageValue;
  selfie: ImageValue;
  front_image_metadata?: string;
  back_image_metadata?: string;
  passport_image_metadata?: string;
}
export type DefaultSideProps = Pick<
  FormStepComponentProps<DocumentsAndSelfieStepValue>,
  'registerField' | 'onChange' | 'errors' | 'onError'
>;
