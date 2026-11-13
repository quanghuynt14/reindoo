import { Link, createFileRoute, redirect } from '@tanstack/react-router'
import {
  ArrowLeftRight,
  Check,
  Clock,
  FileCheck,
  Film,
  Gamepad2,
  Languages,
  Search,
  Star,
  X,
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import { LandingHeader } from '@/components/landing/LandingHeader'
import { LandingFooter } from '@/components/landing/LandingFooter'
import {
  ENGLISH_SPECIMEN,
  EntrySpecimen,
  FRENCH_SPECIMEN,
  NotFoundSpecimen,
} from '@/components/landing/EntrySpecimen'
import { ANCHOR_OFFSET, SECTION } from '@/components/landing/sections'

/**
 * reindoo.com.
 *
 * Cette route redirigeait vers `/dictionary`, ce qui laissait la racine sans
 * rien à montrer à quelqu'un qui n'a pas encore de compte. Elle porte
 * maintenant la page de vente — et la redirection reste, mais seulement pour
 * les gens connectés : `LoginForm` renvoie sur « / » après une connexion
 * réussie, et personne ne veut relire un argumentaire juste après avoir dit
 * oui.
 */
export const Route = createFileRoute('/')({
  beforeLoad: ({ context }) => {
    if (context.session) {
      throw redirect({ to: '/dictionary' })
    }
  },
  component: LandingPage,
})

/** Les sept écrans de l'app, groupés par ce qu'on vient y faire. */
const TOOLS = [
  {
    icon: Languages,
    title: 'Từ điển',
    body: 'Một ô tìm kiếm, một câu trả lời. Pháp → Việt và Anh → Việt.',
  },
  {
    icon: Film,
    title: 'Lướt ôn',
    body: 'Lướt qua những từ đã tra, từng thẻ một, như lướt mạng xã hội.',
  },
  {
    icon: Clock,
    title: 'Lịch sử',
    body: 'Mọi từ bạn từng tra, còn nguyên, tìm lại được.',
  },
  {
    icon: Star,
    title: 'Đã lưu',
    body: 'Gắn sao một từ và nó ở lại, không trôi đi mất.',
  },
  {
    icon: FileCheck,
    title: 'Kiểm tra ngữ pháp',
    body: 'Dán một câu tiếng Pháp hoặc tiếng Anh, xem nó hỏng ở đâu.',
  },
  {
    icon: ArrowLeftRight,
    title: 'Đối chiếu bản dịch',
    body: 'Bản dịch của bạn có nói đúng điều bản gốc nói không.',
  },
  {
    icon: Gamepad2,
    title: 'Trò chơi',
    body: 'Ôn từ bằng cách chơi, chứ không phải bằng cách ngồi học.',
  },
]

/**
 * Basecamp pose vingt et une questions et répond « oui » à chacune. La liste
 * n'impressionne que si chaque ligne est vraie : celles-ci sont toutes prises
 * dans du code qui tourne. Les deux dernières répondent « không », et c'est le
 * but — une liste de vingt oui d'affilée ne se lit plus.
 */
const CHECKLIST: Array<{ question: string; yes: boolean }> = [
  { question: 'Gõ « allions », ra trang của « aller »?', yes: true },
  { question: 'Vẫn thấy đúng dạng mình đã gõ trên màn hình?', yes: true },
  { question: 'Gõ « went », có luôn cả « go » để bấm sang?', yes: true },
  { question: 'Gõ sai chính tả, vẫn gợi ý được từ gần nhất?', yes: true },
  { question: 'Có phiên âm IPA?', yes: true },
  { question: 'Bấm một cái là máy đọc to từ đó?', yes: true },
  { question: 'Có đồng nghĩa và trái nghĩa?', yes: true },
  { question: 'Có câu ví dụ, kèm bản dịch tiếng Việt?', yes: true },
  { question: 'Gắn sao một từ để dành lại?', yes: true },
  { question: 'Xem lại toàn bộ lịch sử tra cứu?', yes: true },
  { question: 'Chia sẻ một mục từ bằng một đường link?', yes: true },
  { question: 'Người nhận mở link ra đúng mục từ đó?', yes: true },
  { question: 'Có bảng lệnh ⌘K để tra mà không rời bàn phím?', yes: true },
  { question: 'Có chế độ tối?', yes: true },
  { question: 'Dùng được trên điện thoại?', yes: true },
  { question: 'Mỗi nghĩa đều dẫn về bài Wiktionary gốc?', yes: true },
  { question: 'Nói thẳng khi không có từ, thay vì bịa ra một nghĩa?', yes: true },
  { question: 'Chạy được mà không cần hỏi một mô hình ngôn ngữ nào?', yes: true },
  { question: 'Có quảng cáo chen vào giữa mục từ?', yes: false },
  { question: 'Có bán lịch sử tra cứu của bạn cho ai không?', yes: false },
]

/**
 * Les deux premiers chiffres sont ceux de `EXPECTED`, dans
 * `packages/server/src/scripts/checkLexicon.ts` — c'est la liste que le
 * canari tient à jour, et donc la seule qui suive un reseed. (Le commentaire
 * de `packages/shared/src/constants.ts` porte encore les totaux d'avant le
 * rattrapage ; ne pas s'en servir.)
 *
 * Ils sont écrits à la main : une page de vente qui recompte ses entrées à
 * chaque visite fait une requête pour un argument. Le prix, c'est qu'ils
 * vieillissent — ils l'ont déjà fait une fois, entre l'écriture de cette page
 * et sa mise en ligne. Quand `EXPECTED` bouge, c'est ici qu'il faut revenir.
 */
const NUMBERS = [
  { value: '46.160', label: 'mục từ tiếng Pháp' },
  { value: '119.108', label: 'mục từ tiếng Anh' },
  { value: '2', label: 'cặp ngôn ngữ, và chỉ hai' },
  { value: '1', label: 'nguồn, kiểm chứng được từng dòng' },
]

function LandingPage() {
  return (
    <div id="top" className="min-h-screen bg-background">
      <LandingHeader />

      {/* ── Hero ─────────────────────────────────────────────────────────── */}
      <section className="mx-auto max-w-6xl px-4 pt-16 pb-20 sm:px-6 sm:pt-24">
        <div className="grid items-start gap-12 lg:grid-cols-[1fr_minmax(0,26rem)]">
          <div>
            <p className="mb-4 text-sm font-semibold tracking-wide text-brand uppercase">
              Pháp → Việt · Anh → Việt
            </p>
            <h1 className="text-4xl font-bold tracking-tight text-balance sm:text-5xl">
              Cuốn từ điển thẳng thắn đến mức dễ chịu: tra một từ, hiểu ngay, và luôn biết
              nghĩa đó đến từ đâu.
            </h1>
            <p className="mt-6 max-w-xl text-lg text-muted-foreground">
              46.160 mục từ tiếng Pháp và 119.108 mục từ tiếng Anh, giải nghĩa bằng tiếng
              Việt, biên dịch sẵn từ Wiktionary. Không có mô hình ngôn ngữ nào đoán hộ bạn.
            </p>

            <div className="mt-8 flex flex-wrap items-center gap-3">
              <Button asChild size="lg" className="h-11 px-6 text-base">
                <Link to="/signup">Dùng thử miễn phí</Link>
              </Button>
              <Button asChild variant="ghost" size="lg" className="h-11 px-4 text-base">
                <Link to="/login">Đã có tài khoản? Đăng nhập →</Link>
              </Button>
            </div>
            <p className="mt-4 text-sm text-muted-foreground">
              Miễn phí. Không cần thẻ. Không quảng cáo.
            </p>

            {/* La barre de recherche de `/dictionary`, en décor : elle dit à quoi
                ressemble l'app avant qu'on ait à créer un compte pour le voir.
                `aria-hidden` parce que c'est un dessin — un lecteur d'écran qui
                annonce « Tra » ici propose un bouton qui n'existe pas, et la
                légende juste en dessous dit déjà la même chose en toutes
                lettres. */}
            <div
              aria-hidden="true"
              className="mt-10 flex items-center gap-3 rounded-full border-2 bg-background px-5 py-3 shadow-lg"
            >
              <Search className="h-5 w-5 shrink-0 text-muted-foreground" />
              <span className="font-serif text-base text-muted-foreground sm:text-lg">
                allions
              </span>
              <span className="ml-auto rounded-full bg-primary px-4 py-1.5 text-sm text-primary-foreground">
                Tra
              </span>
            </div>
          </div>

          <div className="lg:pt-8">
            <EntrySpecimen entry={FRENCH_SPECIMEN} />
            <p className="mt-3 text-center text-sm text-muted-foreground">
              Bạn gõ <span className="font-serif">allions</span>, trang mở ra là{' '}
              <span className="font-serif">aller</span> — và dòng đầu nói rõ vì sao.
            </p>
          </div>
        </div>
      </section>

      {/* ── Les sept écrans ──────────────────────────────────────────────── */}
      <section id={SECTION.tools} className={`border-t bg-muted/30 ${ANCHOR_OFFSET}`}>
        <div className="mx-auto max-w-6xl px-4 py-20 sm:px-6">
          <h2 className="max-w-2xl text-3xl font-bold tracking-tight text-balance sm:text-4xl">
            Tra xong một từ vẫn chưa phải là thuộc nó.
          </h2>
          <p className="mt-4 max-w-2xl text-lg text-muted-foreground">
            Nên ngoài ô tìm kiếm còn sáu chỗ nữa — và cả bảy đều ăn chung một cuốn từ điển.
          </p>

          <div className="mt-12 grid gap-x-8 gap-y-10 sm:grid-cols-2 lg:grid-cols-3">
            {TOOLS.map((tool) => (
              <div key={tool.title}>
                <tool.icon className="h-6 w-6 text-brand" aria-hidden="true" />
                <h3 className="mt-3 text-lg font-semibold">{tool.title}</h3>
                <p className="mt-1 text-muted-foreground">{tool.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── « Tell me if this sounds about right. » ───────────────────────── */}
      <section className="mx-auto max-w-3xl px-4 py-24 sm:px-6">
        <h2 className="text-3xl font-bold tracking-tight text-balance sm:text-4xl">
          Nói xem có đúng thế này không.
        </h2>
        <div className="mt-8 space-y-5 text-lg leading-relaxed text-muted-foreground">
          <p>
            Bạn đang đọc một bài báo tiếng Pháp. Có một từ bạn không biết.
          </p>
          <p>
            Bạn dán nó vào một ô dịch tự động và nhận về đúng một từ tiếng Việt. Không ví
            dụ, không biết nó dùng trong ngữ cảnh nào, không biết nó trang trọng hay suồng
            sã.
          </p>
          <p>
            Bạn hỏi một con AI. Nó trả lời trôi chảy, tự tin, đầy đủ — và bạn không có cách
            nào biết được nó đúng hay nó vừa bịa ra.
          </p>
          <p>
            Thế là bạn mở thêm bốn tab. Đến tab thứ tư thì bạn quên mất câu đang đọc là câu
            gì.
          </p>
          <p className="text-foreground">
            Reindoo làm một việc, và làm hết việc đó:{' '}
            <span className="font-semibold">cho bạn đọc được một từ bạn chưa biết</span>.
            Mọi thứ khác đứng dẹp sang bên.
          </p>
        </div>
      </section>

      {/* ── Les chiffres ─────────────────────────────────────────────────── */}
      <section className="border-y bg-muted/30">
        <div className="mx-auto grid max-w-6xl grid-cols-2 gap-8 px-4 py-16 sm:px-6 lg:grid-cols-4">
          {NUMBERS.map((number) => (
            <div key={number.label}>
              <div className="text-4xl font-bold tracking-tight sm:text-5xl">
                {number.value}
              </div>
              <div className="mt-2 text-sm text-muted-foreground">{number.label}</div>
            </div>
          ))}
        </div>
      </section>

      {/* ── Le modèle de langue est parti ────────────────────────────────── */}
      <section
        id={SECTION.noAi}
        className={`mx-auto max-w-6xl px-4 py-24 sm:px-6 ${ANCHOR_OFFSET}`}
      >
        <div className="grid items-center gap-12 lg:grid-cols-2">
          <div>
            <h2 className="text-3xl font-bold tracking-tight text-balance sm:text-4xl">
              Từ điển này từng đi hỏi một mô hình ngôn ngữ. Chúng tôi đã gỡ nó ra.
            </h2>
            <div className="mt-6 space-y-5 text-lg leading-relaxed text-muted-foreground">
              <p>
                Mô hình trả lời được mọi cặp ngôn ngữ — kể cả những cặp chúng tôi chưa từng
                có một dòng dữ liệu nào. Nó làm được thế vì nó bịa. Một cuốn từ điển biết
                bịa thì trôi chảy hơn, và tệ hơn hẳn.
              </p>
              <p>
                Bây giờ mỗi mục từ đến từ một lexicon đã biên dịch sẵn, đọc thẳng từ cơ sở
                dữ liệu. Từ điển là hữu hạn.
              </p>
              <p className="text-foreground">
                Và vì nó hữu hạn,{' '}
                <span className="font-semibold">« không tìm thấy » là một câu trả lời</span>
                , không phải một lỗi. Màn hình đó không có màu đỏ, không có giọng sự cố. Nó
                nói thẳng là từ ấy không có, đưa ra những từ gần nhất, rồi để bạn bấm.
              </p>
            </div>
          </div>
          <div>
            <NotFoundSpecimen />
          </div>
        </div>
      </section>

      {/* ── La source ────────────────────────────────────────────────────── */}
      <section id={SECTION.source} className={`border-t bg-muted/30 ${ANCHOR_OFFSET}`}>
        <div className="mx-auto max-w-6xl px-4 py-24 sm:px-6">
          <div className="grid items-start gap-12 lg:grid-cols-2">
            <div>
              <h2 className="text-3xl font-bold tracking-tight text-balance sm:text-4xl">
                Mỗi nghĩa đều chỉ ra chỗ nó đến.
              </h2>
              <div className="mt-6 space-y-5 text-lg leading-relaxed text-muted-foreground">
                <p>
                  Nội dung lấy từ Wiktionary tiếng Việt. Có chỗ mỏng, có chỗ cũ — chúng tôi
                  không giấu điều đó.
                </p>
                <p>
                  Nên cuối mỗi mục từ có một dòng: <em>Kiểm tra trên vi.wiktionary</em>. Nó
                  mở ra đúng bài đã sinh ra cái nghĩa bạn vừa đọc.
                </p>
                <p className="text-foreground">
                  Bỏ dòng đó đi thì cuốn từ điển trở nên không thể bắt bẻ — mà{' '}
                  <span className="font-semibold">
                    không thể bắt bẻ không phải là đúng
                  </span>
                  .
                </p>
              </div>
            </div>
            <div>
              <EntrySpecimen entry={ENGLISH_SPECIMEN} />
              <p className="mt-3 text-sm text-muted-foreground">
                <span className="font-serif">went</span> có mục từ riêng, và cả nội dung của
                nó là « dạng quá khứ của go ». Hiện nó một mình là trả cho người đọc một cái
                trỏ thay vì một nghĩa — nên <span className="font-serif">go</span> luôn đi
                kèm, và bấm được.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ── Les deux faces ───────────────────────────────────────────────── */}
      <section
        id={SECTION.typography}
        className={`mx-auto max-w-4xl px-4 py-24 sm:px-6 ${ANCHOR_OFFSET}`}
      >
        <h2 className="text-3xl font-bold tracking-tight text-balance sm:text-4xl">
          Tiếng Pháp nằm trong chữ có chân. Tiếng Việt nằm trong chữ không chân. Không phải
          để cho đẹp.
        </h2>
        <div className="mt-8 space-y-5 text-lg leading-relaxed text-muted-foreground">
          <p>
            Ở cỡ chữ nhỏ, trong một mặt chữ không chân, <span className="font-sans">î</span>{' '}
            và <span className="font-sans">ï</span> phải đoán mới ra. Chân chữ tách chúng ra.
          </p>
          <p>
            Tiếng Việt thì ngược lại: không mặt chữ có chân nào của hệ thống phủ đủ dấu
            thanh. Ba chữ dưới đây phải phân biệt được mà không cần nhìn kỹ, và mặt chữ hệ
            thống làm việc đó tốt nhất.
          </p>
        </div>

        <div className="mt-10 grid gap-4 sm:grid-cols-2">
          <div className="rounded-lg border p-6">
            <div className="text-sm text-muted-foreground">Chữ có chân — tiếng Pháp</div>
            <div className="mt-3 font-serif text-3xl">naïf · maître · île</div>
            <div className="mt-4 border-t pt-4 text-sm text-muted-foreground">
              Cùng ba chữ ấy trong mặt không chân:
            </div>
            <div className="mt-2 font-sans text-3xl text-muted-foreground">
              naïf · maître · île
            </div>
          </div>
          <div className="rounded-lg border p-6">
            <div className="text-sm text-muted-foreground">Chữ không chân — tiếng Việt</div>
            <div className="mt-3 font-sans text-3xl">hòa · hoà · họa</div>
            <div className="mt-4 border-t pt-4 text-sm text-muted-foreground">
              Cùng ba chữ ấy trong mặt có chân:
            </div>
            <div className="mt-2 font-serif text-3xl text-muted-foreground">
              hòa · hoà · họa
            </div>
          </div>
        </div>

        <p className="mt-8 text-lg leading-relaxed text-muted-foreground">
          Nên trên cùng một tấm thẻ: câu ví dụ tiếng Pháp nằm trong chữ có chân, nghĩa tiếng
          Việt nằm trong chữ không chân. Luôn luôn, không có ngoại lệ.
        </p>
      </section>

      {/* ── La liste de questions ────────────────────────────────────────── */}
      <section id={SECTION.checklist} className={`border-t bg-muted/30 ${ANCHOR_OFFSET}`}>
        <div className="mx-auto max-w-4xl px-4 py-24 sm:px-6">
          <h2 className="text-3xl font-bold tracking-tight text-balance sm:text-4xl">
            Nó làm được cái này không?
          </h2>
          <p className="mt-4 text-lg text-muted-foreground">
            Hai mươi câu, và không câu nào cần chú thích nhỏ ở dưới.
          </p>

          <ul className="mt-10 divide-y border-y">
            {CHECKLIST.map((item) => (
              <li key={item.question} className="flex items-center gap-4 py-3.5">
                {item.yes ? (
                  <Check className="h-5 w-5 shrink-0 text-brand" aria-hidden="true" />
                ) : (
                  <X className="h-5 w-5 shrink-0 text-muted-foreground" aria-hidden="true" />
                )}
                <span className="flex-1">{item.question}</span>
                <span
                  className={
                    item.yes
                      ? 'shrink-0 font-semibold'
                      : 'shrink-0 font-semibold text-muted-foreground'
                  }
                >
                  {item.yes ? 'Có.' : 'Không.'}
                </span>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* ── L'appel final ────────────────────────────────────────────────── */}
      <section className="mx-auto max-w-3xl px-4 py-24 text-center sm:px-6">
        <h2 className="text-3xl font-bold tracking-tight text-balance sm:text-4xl">
          Có một từ nào đó bạn đang không biết nghĩa.
        </h2>
        <p className="mx-auto mt-5 max-w-xl text-lg text-muted-foreground">
          Tạo tài khoản mất chưa tới một phút, và từ đầu tiên bạn tra sẽ nói cho bạn biết
          cuốn từ điển này có hợp với bạn không.
        </p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Button asChild size="lg" className="h-11 px-6 text-base">
            <Link to="/signup">Tạo tài khoản miễn phí</Link>
          </Button>
          <Button asChild variant="outline" size="lg" className="h-11 px-6 text-base">
            <Link to="/login">Đăng nhập</Link>
          </Button>
        </div>
        <p className="mt-4 text-sm text-muted-foreground">
          Miễn phí. Không cần thẻ. Không quảng cáo.
        </p>
      </section>

      <LandingFooter />
    </div>
  )
}
