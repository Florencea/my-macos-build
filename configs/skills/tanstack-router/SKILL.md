---
name: tanstack-router
description: File-based routing, type-safe search parameters with Zod, routeTree protection, loaders, and navigation standards with TanStack Router. Use when creating or modifying client-side routes, handling query parameters, or configuring TanStack Router.
compatibility: TanStack Router 1.x+, React 19, Vite+
---

# TanStack Router Guidelines

## 1. Routing Architecture & File Conventions

In TanStack Router projects (`maple-relic`, `vp-antd`, `vp-hono`):

- **Route Directory**: Place route modules strictly under `src/routes/`.
  - Root layout: `src/routes/__root.tsx`
  - Index route: `src/routes/index.tsx` (starter landing page)
  - Canary testbed: `src/routes/canary.tsx` (dedicated regression sandbox for integration points)
  - Catch-all route: `src/routes/$.tsx` (redirects or renders 404)
- **Protected Generated File**:
  - `src/routeTree.gen.ts` is strictly managed by `@tanstack/router-plugin/vite`.
  - **NEVER manually edit `src/routeTree.gen.ts`**. It re-generates automatically on dev or build.

---

## 2. Type-Safe Search Parameters (Zod First)

Always validate search query parameters using Zod within `validateSearch`:

```tsx
import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

const SearchParamsSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  query: z.string().default(""),
  filter: z.enum(["all", "active", "completed"]).default("all"),
});

export type SearchParams = z.infer<typeof SearchParamsSchema>;

export const Route = createFileRoute("/items")({
  validateSearch: (search: Record<string, unknown>): SearchParams => {
    const result = SearchParamsSchema.safeParse(search);
    if (!result.success) {
      return { page: 1, query: "", filter: "all" }; // Fallback defaults
    }
    return result.data;
  },
  component: ItemsPage,
});

function ItemsPage() {
  const { page, query, filter } = Route.useSearch();
  // page is number, query is string, filter is 'all' | 'active' | 'completed'
  return <div>Page {page}</div>;
}
```

---

## 3. Data Loading & SSR/SSG Loaders

- **Loaders over Effects**: ALWAYS load initial route data using `loader` functions rather than `useEffect`:
  ```tsx
  export const Route = createFileRoute("/users/$userId")({
    loader: async ({ params: { userId } }) => {
      const res = await fetch(`/api/users/${userId}`);
      if (!res.ok) throw new Error("User not found");
      return (await res.json()) as UserData;
    },
    component: UserProfilePage,
  });

  function UserProfilePage() {
    const user = Route.useLoaderData();
    return <h1>{user.name}</h1>;
  }
  ```
- **TanStack Query Integration**:
  - In projects pairing Router with TanStack Query, pass `queryClient` to loaders using `queryClient.ensureQueryData(queryOptions)` to populate server state ahead of render.

---

## 4. Type-Safe Navigation & Links

- **Type-Safe `Link`**:
  ```tsx
  import { Link } from "@tanstack/react-router";

  <Link to="/items" search={{ page: 1, query: "search-term", filter: "active" }}>
    View Items
  </Link>;
  ```
- **Programmatic Navigation (`useNavigate`)**:
  ```tsx
  const navigate = useNavigate();

  function handleFilterChange(filter: "all" | "active" | "completed") {
    navigate({
      to: "/items",
      search: (prev) => ({ ...prev, filter, page: 1 }),
    });
  }
  ```

---

## 5. Authoritative Documentation Endpoints

Inspect live TanStack Router documentation using `webread <url>`:

- Router Overview: `webread https://tanstack.com/router/latest/docs/framework/react/overview`
- Search Params Guide: `webread https://tanstack.com/router/latest/docs/framework/react/guide/search-params`
- Data Loading: `webread https://tanstack.com/router/latest/docs/framework/react/guide/data-loading`
