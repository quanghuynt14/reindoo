import { Outlet, createFileRoute, redirect } from '@tanstack/react-router'

// Use the session provided by the root route context (SSR-aware)
export const Route = createFileRoute('/_authenticated')({
  beforeLoad: ({ context, location }) => {
    if (!context.session) {
      throw redirect({
        to: '/login',
        search: { redirect: location.href },
      })
    }
  },
  component: () => <Outlet />,
})
