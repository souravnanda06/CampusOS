import * as React from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { searchApi, type SearchResultItem } from './api/search-api';
import { PageHeader } from '@/components/ui/page-header';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/ui/empty-state';
import {
  Search,
  ArrowRight,
  FileText,
  AlertCircle,
  CreditCard,
  Building,
  UserCheck,
  Megaphone,
  BookOpen,
} from 'lucide-react';

export const SearchPage: React.FC = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const navigate = useNavigate();
  const queryParam = searchParams.get('q') || '';
  const [inputValue, setInputValue] = React.useState(queryParam);
  const [selectedCategory, setSelectedCategory] = React.useState<string>('ALL');

  React.useEffect(() => {
    setInputValue(queryParam);
  }, [queryParam]);

  const { data, isLoading, error } = useQuery({
    queryKey: ['global-search', queryParam],
    queryFn: () => searchApi.search(queryParam),
    enabled: queryParam.trim().length >= 2,
  });

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (inputValue.trim()) {
      setSearchParams({ q: inputValue.trim() });
    }
  };

  const getAdminRouteForCategory = (category: string) => {
    switch (category.toLowerCase()) {
      case 'document':
        return '/documents';
      case 'complaint':
        return '/complaints';
      case 'fee record':
      case 'fee':
        return '/fees';
      case 'hostel & room':
      case 'hostel':
        return '/hostel';
      case 'visitor pass':
      case 'visitor':
        return '/visitors';
      case 'class update':
      case 'academic':
        return '/academic';
      default:
        return '/notices';
    }
  };

  const getCategoryIcon = (category: string) => {
    switch (category.toLowerCase()) {
      case 'document':
        return <FileText className="h-4 w-4 text-amber-500" />;
      case 'complaint':
        return <AlertCircle className="h-4 w-4 text-rose-500" />;
      case 'fee record':
      case 'fee':
        return <CreditCard className="h-4 w-4 text-emerald-500" />;
      case 'hostel & room':
      case 'hostel':
        return <Building className="h-4 w-4 text-purple-500" />;
      case 'visitor pass':
      case 'visitor':
        return <UserCheck className="h-4 w-4 text-blue-500" />;
      case 'class update':
        return <BookOpen className="h-4 w-4 text-cyan-500" />;
      default:
        return <Megaphone className="h-4 w-4 text-indigo-500" />;
    }
  };

  const results = data?.results || [];
  const categories = ['ALL', ...Array.from(new Set(results.map((r) => r.category)))];

  const filteredResults = React.useMemo(() => {
    if (selectedCategory === 'ALL') return results;
    return results.filter((r) => r.category === selectedCategory);
  }, [results, selectedCategory]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Global Institutional Search"
        subtitle="Universal index across notices, documents, complaints, fee ledgers, hostel records, and visitor passes."
      />

      {/* Search Input Bar */}
      <form onSubmit={handleSearchSubmit} className="flex gap-2 max-w-2xl">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
          <Input
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            placeholder="Search students, document types, complaint keywords, notices, fee receipts..."
            className="pl-9 h-10 text-sm"
          />
        </div>
        <Button type="submit" className="h-10 px-5">
          Search
        </Button>
      </form>

      {/* Category Pills */}
      {categories.length > 1 && (
        <div className="flex flex-wrap items-center gap-2">
          {categories.map((cat) => (
            <Button
              key={cat}
              size="sm"
              variant={selectedCategory === cat ? 'default' : 'outline'}
              onClick={() => setSelectedCategory(cat)}
              className="text-xs h-7 rounded-full"
            >
              {cat}
              {cat !== 'ALL' && (
                <span className="ml-1.5 opacity-70">
                  ({results.filter((r) => r.category === cat).length})
                </span>
              )}
            </Button>
          ))}
        </div>
      )}

      {/* Search Content */}
      {isLoading ? (
        <div className="space-y-3">
          <Skeleton className="h-20 w-full" />
          <Skeleton className="h-20 w-full" />
          <Skeleton className="h-20 w-full" />
        </div>
      ) : error ? (
        <div className="rounded-md bg-destructive/10 p-4 text-xs text-destructive">
          Search query failed: {error instanceof Error ? error.message : 'Unknown error'}
        </div>
      ) : !queryParam.trim() ? (
        <EmptyState
          icon={Search}
          title="Begin an institutional search"
          description="Type at least 2 characters above to search across all operational records."
        />
      ) : filteredResults.length === 0 ? (
        <EmptyState
          icon={Search}
          title={`No results found for "${queryParam}"`}
          description="Try broadening your terms, checking spelling, or resetting category filters."
        />
      ) : (
        <div className="space-y-2.5">
          <div className="text-xs text-muted-foreground font-mono">
            Showing {filteredResults.length} matching entities
          </div>

          {filteredResults.map((item: SearchResultItem) => (
            <div
              key={`${item.category}-${item.id}`}
              onClick={() => navigate(getAdminRouteForCategory(item.category))}
              className="group flex items-center justify-between p-4 rounded-lg border border-border bg-card hover:border-primary/40 hover:shadow-xs transition-all cursor-pointer"
            >
              <div className="flex items-start gap-3 flex-1 min-w-0">
                <div className="p-2 rounded-md bg-muted/60 mt-0.5 shrink-0">
                  {getCategoryIcon(item.category)}
                </div>

                <div className="space-y-1 min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span className="font-semibold text-sm text-foreground truncate">
                      {item.title}
                    </span>
                    <Badge variant="secondary" className="text-[10px] uppercase font-mono px-1.5 py-0 shrink-0">
                      {item.category}
                    </Badge>
                    {item.relevance === 'High' && (
                      <Badge variant="default" className="text-[9px] uppercase px-1 py-0 shrink-0">
                        Exact Match
                      </Badge>
                    )}
                  </div>
                  <p className="text-xs text-muted-foreground truncate">
                    {item.subtitle}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-1 text-xs text-muted-foreground group-hover:text-primary transition-colors shrink-0 ml-4">
                <span>View</span>
                <ArrowRight className="h-3.5 w-3.5" />
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
