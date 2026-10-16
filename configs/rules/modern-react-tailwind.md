---
trigger: glob
globs: "**/*.tsx, **/*.jsx, **/*.css"
description: React 19 paradigms, official 'You Might Not Need an Effect' rules, TanStack Router conventions, and Tailwind CSS v4 styling standards.
---

# Modern React 19, Official Best Practices & Tailwind CSS v4 Rules

## 1. React Official Best Practice: You Might Not Need an Effect

Effects are an escape hatch to synchronize with external systems. When no external system is involved, **NEVER use an Effect**. Follow these 12 official rules:

1. **Transforming Data for Rendering (Derived State)**:
   - ❌ `useEffect(() => { setFullName(first + ' ' + last); }, [first, last]);`
   - ✅ Calculate directly in render: `const fullName = first + ' ' + last;`
2. **Caching Expensive Computations**:
   - ❌ Do not store computation results in state updated via an Effect.
   - ✅ Rely on React Compiler auto-memoization, or use `useMemo(() => compute(items), [items])`.
3. **Resetting All State When a Prop Changes**:
   - ❌ Do not write an Effect that listens to `userId` to reset comments: `useEffect(() => { setComment(''); }, [userId]);` (causes extra render pass & flashes stale UI).
   - ✅ Split into an inner component with a `key`: `<Profile userId={userId} key={userId} />`. React resets state automatically.
4. **Adjusting Some State When a Prop Changes**:
   - ❌ Do not adjust state in an Effect when a prop changes.
   - ✅ Prefer deriving the value in render. If adjustment is truly unavoidable, store the previous prop value during render and adjust state inline.
5. **Sharing Logic Between Event Handlers**:
   - ❌ Do not update state just to trigger an Effect that performs user-driven actions (e.g. notifications or buying).
   - ✅ Put user-driven logic directly inside event handlers or shared helper functions. Effects are ONLY for code that runs _because the component was displayed_.
6. **Sending POST Requests & Mutations**:
   - ❌ Never send mutation requests (e.g. `/api/buy`) inside an Effect.
   - ✅ Mutations must be triggered by specific event handlers (e.g. `handleBuy`) or Server Actions.
7. **Chains of Computations (No Effect Cascades)**:
   - ❌ Avoid chains of Effects where Effect A updates State B, which triggers Effect C updating State D.
   - ✅ Calculate all interdependent state updates together inside the triggering event handler, or derive them in render.
8. **Initializing the Application**:
   - ❌ Do not run one-time app setup logic inside a root component's Effect (runs twice in Strict Mode).
   - ✅ Run initialization at top-level module scope or guard with a global variable: `if (typeof window !== 'undefined' && !didInit) { didInit = true; initApp(); }`.
9. **Notifying Parent Components About State Changes**:
   - ❌ Do not listen to internal state inside an Effect to call `onChange(state)`.
   - ✅ Call `onChange` directly within the event handler that updates state, or lift state up to the parent component.
10. **Passing Data to the Parent**:
    - ❌ Do not let child components fetch data and pass it up via an Effect callback.
    - ✅ Let the parent fetch or load the data and pass it down as props.
11. **Subscribing to an External Store**:
    - ❌ Do not manually subscribe with `useEffect` + `useState`.
    - ✅ Use the built-in `useSyncExternalStore` hook.
12. **Fetching Data**:
    - ❌ Do not write manual `useEffect` + `fetch` calls without cleanup.
    - ✅ Prefer route-level loaders (e.g. TanStack Router `loader`), React Server Components (RSC), or `use(Promise)` / TanStack Query. If manual Effect fetching is unavoidable, ALWAYS implement an active flag or `AbortController` cleanup to prevent race conditions.

---

## 2. React 19 Core Paradigms

- **Direct Ref Passing**: Pass `ref` directly as a standard component prop. STRICTLY PROHIBITED to use `React.forwardRef`. Destructure `{ ref, ...props }` in parameter lists.
- **Explicit Component Typing**: STRICTLY PROHIBITED to use `React.FC` or `React.FunctionComponent`. Explicitly declare prop interfaces (e.g. `interface ButtonProps`) and type `children` as `React.ReactNode`.
- **Server Actions for Mutations**: Prefer `<form action={serverAction}>` paired with `useActionState` and `useFormStatus`. Avoid legacy `onSubmit` handlers paired with `e.preventDefault()`.
- **Async Resource Unwrapping**: Use `use(Promise)` or `use(Context)` to unwrap resources. NEVER use `useEffect` for initial data fetching.
- **Optimistic UI**: Use `useOptimistic` for instantaneous UI state updates before action completion.
- **Automatic Memoization (React Compiler)**: When `@vitejs/plugin-react` has `compiler: true` (paired with `oxc-transform-react`), NEVER manually add `useMemo`, `useCallback`, or `React.memo` unless handling explicit compiler bailouts.
- **Server/Client Boundaries**: Default components to React Server Components (RSC). Add `"use client"` only when accessing browser APIs, state hooks, or event listeners.

---

## 3. Tailwind CSS v4 Rules

- **Design Token SSOT (`@theme`)**: Tailwind CSS v4 `@theme` in the root CSS file is the sole source of truth for design tokens. Bridge tokens to UI libraries (e.g. Ant Design tokens, Spectrum) via CSS variables. Never hardcode magic colors or use inline `style={{ ... }}` overrides.
- **Canonical Class Validation**: Maintain zero warnings on `vpr lint:tailwind`. All classes must conform to Tailwind v4 canonical syntax.
- **No Dynamic Class Interpolation**: NEVER dynamically interpolate class strings (e.g. `bg-blue-${shade}`). Use complete class literals or lookup record maps so the scanner detects them.
- **Merge Classes Reliably**: NEVER concatenate class strings manually. Always use `clsx` and `tailwind-merge` (typically wrapped as `cn(...)`) to resolve CSS specificity conflicts.
- **Native CSS Variables & `@theme`**: Leverage Tailwind v4 `@theme` directives and CSS custom properties instead of legacy JS configuration files (`tailwind.config.js`).
- **Restrict `@apply`**: Stick to utility classes directly in markup. Avoid extracting utilities via `@apply` into CSS files except for base resets.

---

## 4. Routing Conventions (TanStack Router)

In projects using TanStack Router:

- **Route Directory**: Place route modules strictly under `src/routes/`.
- **Protected Route Tree**: NEVER manually edit `src/routeTree.gen.ts`. It is automatically generated and synchronized by the router plugin.
- **Type-Safe Search Parameters**: Validate query parameters using `validateSearch` on `createFileRoute` paired with Zod schemas.
- **Type-Safe Navigation**: Use `useNavigate` and `Link` components with typed `search` and `params` arguments.
