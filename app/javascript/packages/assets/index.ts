// eslint-disable-next-line no-underscore-dangle
const ASSET_PATHS: Record<string, string> | undefined = (global as any)._asset_paths;

export const getAssetPath = (path) => ASSET_PATHS?.[path];
