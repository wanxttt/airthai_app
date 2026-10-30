export interface CopilotResponse {
  answer: string;
  periodAnalyzed: string;
  dataUsed: string[];
  calculationDefinition?: string;
  caveats: string[];
  recommendedNextStep: string;
  dataFreshness: string;
  deterministicFigures?: Record<string, any>;
  isAvailable: boolean;
}

export interface CopilotSuggestion {
  id: string;
  category: 'SALES' | 'RECEIVABLES' | 'INVENTORY' | 'EXPENSES' | 'TRENDS' | 'REVIEW';
  question: string;
}

