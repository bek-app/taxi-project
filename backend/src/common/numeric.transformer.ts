export const numericTransformer = {
  to: (value: number): number => value,
  from: (value: string | number | null): number => {
    if (value === null || value === undefined) {
      return 0;
    }

    if (typeof value === 'number') {
      return value;
    }

    return Number(value);
  },
};
