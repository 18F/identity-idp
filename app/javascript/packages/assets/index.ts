type AssetPaths = Record<string, string> | undefined;

// eslint-disable-next-line no-underscore-dangle
export const getAssetPath = (path) => ((global as any)._asset_paths as AssetPaths)?.[path];
