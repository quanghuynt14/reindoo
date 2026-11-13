import { Link } from '@tanstack/react-router'
import { Button } from '@/components/ui/button'
import { SECTION, anchor } from '@/components/landing/sections'

/**
 * L'en-tête de la page de vente, et pas celui de l'app.
 *
 * Le `Header` de l'application pointe vers sept routes qui sont toutes derrière
 * `_authenticated` : offert à un visiteur déconnecté, chacun de ces liens est
 * un aller simple vers l'écran de connexion. Ici les liens mènent aux sections
 * de la page, et le seul chemin vers l'app est l'inscription.
 *
 * Pas de sélecteur de thème : la page suit celui du système, comme Basecamp.
 * Un bouton de plus dans une barre de vente est un choix de plus à faire avant
 * d'avoir compris ce qu'on vend.
 */

const NAV = [
  { id: SECTION.tools, label: 'Công cụ' },
  { id: SECTION.noAi, label: 'Vì sao không có AI' },
  { id: SECTION.source, label: 'Nguồn dữ liệu' },
  { id: SECTION.checklist, label: 'Nó làm được gì' },
]

export function LandingHeader() {
  return (
    <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-backdrop-filter:bg-background/60">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-4 px-4 sm:px-6">
        <a href="#top" className="flex shrink-0 items-baseline gap-1.5">
          <span className="text-xl font-bold tracking-tight">Reindoo</span>
          <span aria-hidden="true" className="text-xl leading-none text-brand">
            .
          </span>
        </a>

        <nav className="hidden items-center gap-6 md:flex">
          {NAV.map((item) => (
            <a
              key={item.id}
              href={anchor(item.id)}
              className="text-sm text-muted-foreground transition-colors hover:text-foreground"
            >
              {item.label}
            </a>
          ))}
        </nav>

        <div className="flex shrink-0 items-center gap-2">
          <Button asChild variant="ghost" size="sm">
            <Link to="/login">Đăng nhập</Link>
          </Button>
          <Button asChild size="sm">
            <Link to="/signup">Dùng thử miễn phí</Link>
          </Button>
        </div>
      </div>
    </header>
  )
}
