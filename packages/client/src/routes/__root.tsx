import { HeadContent, Scripts, createRootRouteWithContext, useRouteContext, useRouterState } from '@tanstack/react-router'
import { TanStackRouterDevtoolsPanel } from '@tanstack/react-router-devtools'
import { TanStackDevtools } from '@tanstack/react-devtools'
import { QueryClientProvider } from '@tanstack/react-query'

import Header from '../components/Header'
import { ThemeProvider } from '../lib/theme'
import { AuthProvider } from '../lib/auth-context'
import { Toaster } from '../components/ui/sonner'
import { CommandPalette } from '../components/CommandPalette'
import { queryClient } from '../lib/query-client'

import appCss from '../styles.css?url'
import { getCurrentSession } from '@/lib/auth-server'

// Blocking script to prevent FOUC by applying theme before first paint
const createThemeScript = (theme: 'dark' | 'light' | 'system') => {
  const script = `
    (function() {
      try {
        const stored = localStorage.getItem('dictionary-theme') || ${JSON.stringify(theme)};
        const resolved = stored === 'system' 
          ? (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')
          : stored;
        document.documentElement.classList.add(resolved);
      } catch (e) {}
    })();
  `;
  return script;
};

export const Route = createRootRouteWithContext()({
  beforeLoad: async () => {
    const data = await getCurrentSession();

    return { session: data };
  },
  head: () => ({
    meta: [
      {
        charSet: 'utf-8',
      },
      {
        name: 'viewport',
        content: 'width=device-width, initial-scale=1',
      },
      {
        title: 'Reindoo — Học tiếng Anh, tiếng Pháp bằng tiếng Việt',
      },
      {
        name: 'description',
        content: 'Từ điển, kiểm tra ngữ pháp và đối chiếu bản dịch, giải thích bằng tiếng Việt.',
      },
      {
        name: 'color-scheme',
        content: 'dark light',
      },
    ],
    links: [
      {
        rel: 'stylesheet',
        href: appCss,
      },
    ],
  }),

  shellComponent: RootDocument,
})

function RootContent({ children }: { children: React.ReactNode }) {
  const routerState = useRouterState();
  const currentPath = routerState.location.pathname;
  // La racine porte maintenant une page de vente avec son propre en-tête. Le
  // Header de l'app y serait pire qu'inutile : ses sept liens sont tous
  // derrière `_authenticated`, donc tous des allers simples vers /login pour
  // le visiteur qui vient de découvrir le produit.
  const hideHeader =
    currentPath === '/' || currentPath === '/login' || currentPath === '/signup';

  return (
    <>
      {!hideHeader && <Header />}
      {children}
      <CommandPalette />
      <Toaster />
      <TanStackDevtools
        config={{
          position: 'bottom-right',
        }}
        plugins={[
          {
            name: 'Tanstack Router',
            render: <TanStackRouterDevtoolsPanel />,
          },
        ]}
      />
    </>
  )
}

function RootDocument({ children }: { children: React.ReactNode }) {
  const context = useRouteContext({ from: '__root__' });
  return (
    <html lang="vi" suppressHydrationWarning>
      <head>
        <HeadContent />
        <link rel="apple-touch-icon" href="logo192.png"></link>
        <script dangerouslySetInnerHTML={{ __html: createThemeScript('system') }} />
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
      </head>
      <body>
        <QueryClientProvider client={queryClient}>
          <AuthProvider initialSession={context.session}>
            <ThemeProvider defaultTheme="system" storageKey="dictionary-theme">
              <RootContent>{children}</RootContent>
            </ThemeProvider>
          </AuthProvider>
        </QueryClientProvider>
        <Scripts />
      </body>
    </html>
  )
}
