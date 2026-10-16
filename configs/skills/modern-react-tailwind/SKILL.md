---
name: modern-react-tailwind
description: Strict best practices for modern React 19, official 'You Might Not Need an Effect' rules, and Tailwind CSS v4. Use when building React components, server actions, forms, hooks, layout structures, and styling with Tailwind CSS v4.
compatibility: React 19.x, Tailwind CSS 4.x, Vite+
---

# Modern React 19, Official Best Practices & Tailwind CSS v4 Guidelines

## 1. Component Architecture & Effect Decision Tree

Follow this decision tree when designing components, data flows, and state:

- **Server vs Client Boundary**:
  - Default all components to **React Server Components (RSC)**.
  - Add `"use client"` ONLY when the component requires browser APIs, state hooks (`useState`, `useReducer`), event handlers (`onClick`, `onChange`), or custom interactive hooks.
- **Do I Need an Effect? (The Synchronization Test)**:
  - Is it synchronizing with an external system (browser DOM API, non-React widget, WebSocket, external store)? $\rightarrow$ **YES, use an Effect**.
  - Is it transforming data for rendering, handling user events, resetting state on prop change, or updating parent state? $\rightarrow$ **NO, DO NOT USE AN EFFECT**.
- **Form Submissions & Data Mutations**:
  - Always prefer native `<form action={serverAction}>` paired with `useActionState` and `useFormStatus`.
  - Avoid legacy `onSubmit` handlers paired with `e.preventDefault()`.
- **Async Resource Unwrapping**:
  - Use `use(Promise)` or `use(Context)` to unwrap resources directly in render.
  - NEVER use `useEffect` for initial data fetching.
- **Theme & Design Tokens**:
  - Use native Tailwind CSS v4 `@theme` directives and CSS variables.
  - Bridge UI libraries (Ant Design tokens, Spectrum) via CSS variables. Never hardcode colors or use inline `style={{ ... }}` overrides.

---

## 2. React Official Best Practices: You Might Not Need an Effect (12 Scenarios)

Effects are an escape hatch. Follow these 12 concrete patterns directly from React official documentation:

### Scenario 1: Updating State Based on Props or State (Derived State)

- 🔴 **Bad**: Redundant state and extra cascading render pass
  ```tsx
  const [fullName, setFullName] = useState("");
  useEffect(() => {
    setFullName(firstName + " " + lastName);
  }, [firstName, lastName]);
  ```
- 🟢 **Good**: Calculated during rendering
  ```tsx
  const fullName = firstName + " " + lastName;
  ```

### Scenario 2: Caching Expensive Calculations

- 🔴 **Bad**: Updating state from an Effect
  ```tsx
  const [visibleTodos, setVisibleTodos] = useState([]);
  useEffect(() => {
    setVisibleTodos(getFilteredTodos(todos, filter));
  }, [todos, filter]);
  ```
- 🟢 **Good**: Trust React Compiler, or use `useMemo` when profiling demands it
  ```tsx
  const visibleTodos = useMemo(() => getFilteredTodos(todos, filter), [todos, filter]);
  ```

### Scenario 3: Resetting All State When a Prop Changes

- 🔴 **Bad**: Listening to prop changes to reset state (causes extra render pass & flashes stale UI)
  ```tsx
  function Profile({ userId }) {
    const [comment, setComment] = useState("");
    useEffect(() => {
      setComment("");
    }, [userId]);
  }
  ```
- 🟢 **Good**: Pass a unique `key` to the component to tell React it is a different identity
  ```tsx
  <Profile userId={userId} key={userId} />
  ```

### Scenario 4: Adjusting Some State When a Prop Changes

- 🔴 **Bad**: Adjusting state in an Effect
  ```tsx
  useEffect(() => {
    setSelection(null);
  }, [items]);
  ```
- 🟢 **Good**: Derive inline during rendering, or adjust state during render if state must be preserved
  ```tsx
  const [prevItems, setPrevItems] = useState(items);
  const [selectedId, setSelectedId] = useState(null);
  if (items !== prevItems) {
    setPrevItems(items);
    setSelectedId(null);
  }
  ```

### Scenario 5: Sharing Logic Between Event Handlers

- 🔴 **Bad**: Setting state to trigger an Effect
  ```tsx
  const [product, setProduct] = useState(null);
  useEffect(() => {
    if (product) buyProduct(product);
  }, [product]);
  ```
- 🟢 **Good**: Call the shared logic directly from the event handler
  ```tsx
  function handleBuy(product) {
    buyProduct(product);
    showNotification("Purchased!");
  }
  ```

### Scenario 6: Sending POST Requests

- 🔴 **Bad**: Triggering mutations inside an Effect
  ```tsx
  useEffect(() => {
    post("/api/register");
  }, []);
  ```
- 🟢 **Good**: Trigger mutations from user event handlers or Server Actions
  ```tsx
  function handleSubmit() {
    post("/api/register");
  }
  ```

### Scenario 7: Chains of Computations (No Cascading Effects)

- 🔴 **Bad**: Effect chains (Effect 1 triggers Effect 2 which triggers Effect 3)
- 🟢 **Good**: Compute the next states together inside the triggering event handler, or derive them in render.

### Scenario 8: Initializing the Application

- 🔴 **Bad**: Running app setup in a root component's Effect (runs twice in Strict Mode)
- 🟢 **Good**: Top-level module execution or global initialization flag
  ```tsx
  let didInit = false;
  function App() {
    useEffect(() => {
      if (!didInit) {
        didInit = true;
        initAuthToken();
      }
    }, []);
  }
  ```

### Scenario 9: Notifying Parent Components About State Changes

- 🔴 **Bad**: Watching local state in an Effect to notify parent
  ```tsx
  useEffect(() => {
    onChange(isOn);
  }, [isOn]);
  ```
- 🟢 **Good**: Notify parent during the event that causes the change, or lift state up
  ```tsx
  function handleClick() {
    const nextIsOn = !isOn;
    setIsOn(nextIsOn);
    onChange(nextIsOn);
  }
  ```

### Scenario 10: Passing Data to the Parent

- 🔴 **Bad**: Child fetches and passes data up via Effect
- 🟢 **Good**: Parent fetches data and passes it down to child as props.

### Scenario 11: Subscribing to an External Store

- 🔴 **Bad**: Manually subscribing with `useEffect` + `useState`
- 🟢 **Good**: Use React's built-in `useSyncExternalStore`
  ```tsx
  function useOnlineStatus() {
    return useSyncExternalStore(
      subscribe,
      () => navigator.onLine,
      () => true,
    );
  }
  ```

### Scenario 12: Fetching Data

- 🔴 **Bad**: Raw `useEffect` + `fetch` without cleanup (susceptible to race conditions)
- 🟢 **Good**: Route loaders (TanStack Router), React Server Components, or `use(Promise)` / TanStack Query.
  If manual Effect fetching is required, implement cleanup:
  ```tsx
  useEffect(() => {
    let ignore = false;
    async function startFetching() {
      const json = await fetchTodos(userId);
      if (!ignore) setTodos(json);
    }
    startFetching();
    return () => {
      ignore = true;
    };
  }, [userId]);
  ```

---

## 3. React 19 Core Paradigms & Server Actions

- **Direct Ref Passing**: Pass `ref` directly as a regular prop. Never use `React.forwardRef`.
  ```tsx
  interface InputProps {
    ref?: React.Ref<HTMLInputElement>;
    label: string;
  }
  export function Input({ ref, label, ...props }: InputProps) {
    return (
      <label>
        {label}
        <input ref={ref} {...props} />
      </label>
    );
  }
  ```
- **Form Actions & Optimistic State**:
  ```tsx
  import { useActionState, useOptimistic } from "react";

  export function TodoForm({ action }: { action: (prev: State, fd: FormData) => Promise<State> }) {
    const [state, formAction, isPending] = useActionState(action, {
      todos: [],
    });
    const [optimisticTodos, setOptimistic] = useOptimistic(
      state.todos,
      (current, newTitle: string) => [...current, { id: "temp", title: newTitle }],
    );

    return (
      <form
        action={async (fd) => {
          setOptimistic(fd.get("title") as string);
          await formAction(fd);
        }}
      >
        <input name="title" required />
        <button disabled={isPending}>Add</button>
      </form>
    );
  }
  ```

---

## 4. Tailwind CSS v4 Theme Bridge & Styling Standards

### Design Token Single Source of Truth (`@theme`)

In your root CSS file (`src/index.css`), declare theme tokens using Tailwind CSS v4 syntax:

```css
@import "tailwindcss";

@theme {
  --color-primary: #3b82f6;
  --color-brand-accent: #8b5cf6;
  --font-display: "Inter", sans-serif;
}
```

### Bridging External UI Libraries (e.g. Ant Design Tokens)

Bridge external component library theme variables directly to CSS variables defined in `@theme`:

```tsx
import { ConfigProvider } from "antd";

export function AntdProvider({ children }: { children: React.ReactNode }) {
  return (
    <ConfigProvider
      theme={{
        token: {
          colorPrimary: "var(--color-primary)",
          borderRadius: 8,
        },
      }}
    >
      {children}
    </ConfigProvider>
  );
}
```

---

## 5. Authoritative Documentation Endpoints

Inspect live documentation using `webread <url>`:

- React Official Reference: `webread https://react.dev/reference/react`
- You Might Not Need an Effect: `webread https://react.dev/learn/you-might-not-need-an-effect`
- React Compiler: `webread https://react.dev/learn/react-compiler`
- Tailwind CSS v4: `webread https://tailwindcss.com/docs`
