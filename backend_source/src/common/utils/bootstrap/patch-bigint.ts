/**
 * Shared bootstrap utilities.
 * Centralizes monkey-patches that were previously duplicated across entry points.
 */

// BigInt JSON serialization: Prisma returns BigInt for bigint columns,
// Express res.json() can't serialize BigInt natively.
(BigInt.prototype as any).toJSON = function () {
    return this.toString();
};
