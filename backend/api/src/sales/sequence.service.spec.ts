import { SequenceService } from './sequence.service';

describe('SequenceService', () => {
  let service: SequenceService;
  let mockPrisma: any;

  beforeEach(() => {
    mockPrisma = {
      documentSequence: {
        upsert: jest.fn(),
      },
    };
    service = new SequenceService(mockPrisma);
  });

  describe('getFiscalYear', () => {
    it('returns 2026-27 for October 2026', () => {
      const date = new Date(2026, 9, 25); // month index 9 is October
      expect(service.getFiscalYear(date)).toBe('2026-27');
    });

    it('returns 2026-27 for April 2026', () => {
      const date = new Date(2026, 3, 1); // month index 3 is April
      expect(service.getFiscalYear(date)).toBe('2026-27');
    });

    it('returns 2026-27 for March 2027', () => {
      const date = new Date(2027, 2, 31); // month index 2 is March
      expect(service.getFiscalYear(date)).toBe('2026-27');
    });

    it('returns 2027-28 for April 2027', () => {
      const date = new Date(2027, 3, 1);
      expect(service.getFiscalYear(date)).toBe('2027-28');
    });
  });

  describe('getNextNumber', () => {
    it('generates padded number based on upserted sequence', async () => {
      mockPrisma.documentSequence.upsert.mockResolvedValue({
        prefix: 'INV',
        nextNumber: 2, // meaning 1 was allocated
      });

      const num = await service.getNextNumber('biz_1', 'INVOICE', 'INV', new Date(2026, 9, 25));
      expect(num).toBe('INV-2026-27-0001');

      mockPrisma.documentSequence.upsert.mockResolvedValue({
        prefix: 'INV',
        nextNumber: 15, // meaning 14 was allocated
      });
      const num14 = await service.getNextNumber('biz_1', 'INVOICE', 'INV', new Date(2026, 9, 25));
      expect(num14).toBe('INV-2026-27-0014');
    });
  });
});
