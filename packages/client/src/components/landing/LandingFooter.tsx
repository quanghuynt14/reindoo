import { Link } from '@tanstack/react-router'
import { SECTION, anchor } from '@/components/landing/sections'

/**
 * Trois colonnes, et chaque lien mène exactement là où son étiquette le
 * promet.
 *
 * La première version avait quatre colonnes et quatorze liens — « Reels »,
 * « Đã lưu », « Trò chơi » — qui tombaient tous soit sur la grille des outils,
 * soit sur l'inscription. Un pied de page qui promet des pages qui n'existent
 * pas se fait attraper au premier clic, et c'est la confiance qu'on vient
 * justement de passer une page entière à construire.
 *
 * Le reste porte la seule chose qui n'est pas négociable ici : l'attribution.
 * Le contenu vient du Wiktionnaire vietnamien, il est sous CC BY-SA, et une
 * page qui le sert sans le dire s'approprie un travail collectif. Le lien de
 * chaque entrée dit d'où vient une glose ; cette ligne-ci dit sous quelle
 * licence elle circule.
 */

const READ_MORE = [
  { id: SECTION.tools, label: 'Bảy công cụ' },
  { id: SECTION.noAi, label: 'Vì sao không có AI' },
  { id: SECTION.source, label: 'Nguồn dữ liệu' },
  { id: SECTION.typography, label: 'Hai mặt chữ' },
  { id: SECTION.checklist, label: 'Nó làm được gì' },
]

const EXTERNAL = [
  { href: 'https://vi.wiktionary.org', label: 'Wiktionary tiếng Việt' },
  {
    href: 'https://creativecommons.org/licenses/by-sa/3.0/deed.vi',
    label: 'Giấy phép CC BY-SA 3.0',
  },
]

const LINK_CLASS = 'text-sm text-muted-foreground transition-colors hover:text-foreground'

export function LandingFooter() {
  return (
    <footer className="border-t bg-muted/30">
      <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-3">
          <div>
            <h2 className="mb-3 text-sm font-semibold">Đọc thêm</h2>
            <ul className="space-y-2">
              {READ_MORE.map((item) => (
                <li key={item.id}>
                  <a href={anchor(item.id)} className={LINK_CLASS}>
                    {item.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <h2 className="mb-3 text-sm font-semibold">Bắt đầu</h2>
            <ul className="space-y-2">
              <li>
                <Link to="/signup" className={LINK_CLASS}>
                  Tạo tài khoản
                </Link>
              </li>
              <li>
                <Link to="/login" className={LINK_CLASS}>
                  Đăng nhập
                </Link>
              </li>
            </ul>
          </div>

          <div>
            <h2 className="mb-3 text-sm font-semibold">Nguồn</h2>
            <ul className="space-y-2">
              {EXTERNAL.map((item) => (
                <li key={item.href}>
                  <a
                    href={item.href}
                    target="_blank"
                    rel="noreferrer noopener"
                    className={LINK_CLASS}
                  >
                    {item.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        </div>

        <div className="mt-12 space-y-3 border-t pt-8 text-sm text-muted-foreground">
          <p>
            Nội dung từ điển lấy từ Wiktionary tiếng Việt, dùng theo giấy phép CC BY-SA 3.0.
            Mỗi mục từ đều dẫn ngược về bài gốc của nó.
          </p>
          <p>
            <span className="font-semibold text-foreground">Reindoo</span> — một cuốn từ điển,
            không phải một trợ lý.
          </p>
        </div>
      </div>
    </footer>
  )
}
