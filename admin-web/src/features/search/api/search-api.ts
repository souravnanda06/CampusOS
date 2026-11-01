import { apiClient } from '@/services/api/api-client';

export interface SearchResultItem {
  category: string;
  title: string;
  subtitle: string;
  id: string;
  deepLink: string;
  relevance: string;
}

export interface SearchResponse {
  query: string;
  count: number;
  results: SearchResultItem[];
  message?: string;
}

export const searchApi = {
  search: async (q: string): Promise<SearchResponse> => {
    return apiClient.get<SearchResponse>(`/search?q=${encodeURIComponent(q)}`);
  },
};
