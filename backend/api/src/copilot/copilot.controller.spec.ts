import { Test, TestingModule } from '@nestjs/testing';
import { CopilotController } from './copilot.controller';
import { CopilotService } from './copilot.service';
import { AiProviderService } from './ai-provider.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { TenantGuard } from '../auth/guards/tenant.guard';

describe('CopilotController', () => {
  let controller: CopilotController;
  let copilotService: jest.Mocked<CopilotService>;
  let aiProvider: jest.Mocked<AiProviderService>;

  beforeEach(async () => {
    copilotService = {
      isAvailable: jest.fn().mockReturnValue(true),
      getSuggestions: jest.fn().mockReturnValue([
        { id: '1', category: 'SALES', question: 'How much did my business sell?' },
      ]),
      query: jest.fn().mockResolvedValue({
        answer: 'Total sales were ₹10,000.',
        periodAnalyzed: 'October 2026',
        dataUsed: ['Invoices'],
        caveats: ['Draft invoices excluded'],
        recommendedNextStep: 'Collect payments',
        dataFreshness: new Date().toISOString(),
        isAvailable: true,
      }),
    } as any;

    aiProvider = {
      getModelName: jest.fn().mockReturnValue('gpt-4o'),
    } as any;

    const module: TestingModule = await Test.createTestingModule({
      controllers: [CopilotController],
      providers: [
        { provide: CopilotService, useValue: copilotService },
        { provide: AiProviderService, useValue: aiProvider },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(RolesGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(TenantGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<CopilotController>(CopilotController);
  });

  it('getStatus returns copilot availability and model information', () => {
    const res = controller.getStatus();
    expect(res.success).toBe(true);
    expect(res.data.isAvailable).toBe(true);
    expect(res.data.model).toBe('gpt-4o');
    expect(res.data.mode).toBe('READ_ONLY');
  });

  it('getSuggestions returns canonical business questions', () => {
    const res = controller.getSuggestions();
    expect(res.success).toBe(true);
    expect(res.data).toHaveLength(1);
    expect(res.data[0].category).toBe('SALES');
  });

  it('query passes businessId and queryDto to copilot service', async () => {
    const res = await controller.query('biz_123', {
      query: 'How much did my business sell?',
    });

    expect(res.success).toBe(true);
    expect(copilotService.query).toHaveBeenCalledWith('biz_123', {
      query: 'How much did my business sell?',
    });
    expect(res.data.answer).toBe('Total sales were ₹10,000.');
  });
});
