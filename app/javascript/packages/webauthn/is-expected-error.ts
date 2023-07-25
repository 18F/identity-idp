const isExpectedWebauthnError = (error: Error): boolean => error instanceof DOMException;

export default isExpectedWebauthnError;
