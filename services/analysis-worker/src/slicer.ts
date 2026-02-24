export type SliceRect = { x: number; y: number; w: number; h: number };

export const sliceLongImage = (
  width: number,
  height: number,
  sliceHeight = 1800,
  overlapRatio = 0.15,
): SliceRect[] => {
  if (height <= sliceHeight) {
    return [{ x: 0, y: 0, w: width, h: height }];
  }

  const overlap = Math.floor(sliceHeight * overlapRatio);
  const step = Math.max(1, sliceHeight - overlap);
  const slices: SliceRect[] = [];

  let y = 0;
  while (y < height) {
    const h = Math.min(sliceHeight, height - y);
    slices.push({ x: 0, y, w: width, h });
    if (y + h >= height) break;
    y += step;
  }
  return slices;
};
