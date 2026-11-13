import { MoreVertical, Star } from 'lucide-react'
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { Separator } from '@/components/ui/separator'

/**
 * Une entrée du dictionnaire, figée.
 *
 * Ce n'est pas une capture d'écran : c'est le même balisage que
 * `routes/_authenticated/dictionary/index.tsx`, avec des données en dur. Une
 * image se démode dès qu'on touche à la carte ; celle-ci suit les jetons, le
 * thème sombre et les deux faces toute seule.
 *
 * Le partage des polices est la règle de DESIGN.md, et il est visible ici :
 * le mot étranger et l'exemple sont en `font-serif`, la glose vietnamienne et
 * toute la tuyauterie sont dans la face UI.
 */

type Specimen = {
  word: string
  ipa?: string
  /** La forme tapée, quand elle diffère de la vedette : « allions » → « aller ». */
  matchedForm?: string
  /** Une entrée-renvoi ne se montre jamais seule : « went » sans « go » ne dit rien. */
  alsoFrom?: Array<string>
  translated: string
  explain: string
  synonyms?: Array<string>
  antonyms?: Array<string>
  examples: Array<{ source: string; target: string }>
  wiki: string
}

export const FRENCH_SPECIMEN: Specimen = {
  word: 'aller',
  ipa: '/a.le/',
  matchedForm: 'allions',
  translated: 'đi',
  explain: 'Di chuyển từ nơi này đến nơi khác.',
  synonyms: ['se rendre', 'partir'],
  antonyms: ['rester'],
  examples: [
    {
      source: 'Nous allions à la mer chaque été.',
      target: 'Mùa hè nào chúng tôi cũng đi biển.',
    },
  ],
  wiki: 'https://vi.wiktionary.org/wiki/aller',
}

export const ENGLISH_SPECIMEN: Specimen = {
  word: 'went',
  ipa: '/wɛnt/',
  alsoFrom: ['go'],
  translated: 'đã đi',
  explain: 'Dạng quá khứ của go.',
  examples: [
    {
      source: 'She went home before the rain.',
      target: 'Cô ấy về nhà trước khi trời mưa.',
    },
  ],
  wiki: 'https://vi.wiktionary.org/wiki/went',
}

export function EntrySpecimen({ entry }: { entry: Specimen }) {
  return (
    <Card className="w-full">
      <CardHeader>
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <CardTitle className="font-serif text-2xl sm:text-3xl">{entry.word}</CardTitle>
            {entry.ipa && (
              <p className="mt-1 text-sm text-muted-foreground">{entry.ipa}</p>
            )}
            {entry.matchedForm && (
              <p className="mt-1 text-sm text-muted-foreground">
                <span className="font-serif">« {entry.matchedForm} »</span> →{' '}
                <span className="font-serif font-medium text-foreground">{entry.word}</span>
              </p>
            )}
            {entry.alsoFrom && (
              <p className="mt-1 text-sm text-muted-foreground">
                Cũng là dạng của{' '}
                {entry.alsoFrom.map((other, i) => (
                  <span key={other}>
                    {i > 0 && ', '}
                    <span className="font-serif underline underline-offset-2">{other}</span>
                  </span>
                ))}
              </p>
            )}
            <CardDescription className="mt-2 text-lg sm:text-xl">
              {entry.translated}
            </CardDescription>
          </div>
          {/* Les commandes de la vraie carte, en dessin : ici elles ne font
              rien, donc elles ne s'annoncent pas. */}
          <div aria-hidden="true" className="flex items-center gap-1 text-muted-foreground">
            <Star className="h-5 w-5" />
            <MoreVertical className="h-5 w-5" />
          </div>
        </div>
      </CardHeader>
      <Separator />
      <CardContent className="space-y-3">
        <p className="text-muted-foreground">{entry.explain}</p>

        {(entry.synonyms || entry.antonyms) && (
          <div className="flex flex-wrap gap-4 text-sm">
            {entry.synonyms && (
              <div>
                <span className="font-semibold text-green-600 dark:text-green-400">
                  Đồng nghĩa:{' '}
                </span>
                <span className="font-serif text-muted-foreground">
                  {entry.synonyms.join(', ')}
                </span>
              </div>
            )}
            {entry.antonyms && (
              <div>
                <span className="font-semibold text-red-600 dark:text-red-400">
                  Trái nghĩa:{' '}
                </span>
                <span className="font-serif text-muted-foreground">
                  {entry.antonyms.join(', ')}
                </span>
              </div>
            )}
          </div>
        )}

        <div className="space-y-3">
          <h4 className="text-sm font-semibold text-muted-foreground">Ví dụ</h4>
          {entry.examples.map((example) => (
            <div key={example.source} className="border-l-4 border-brand py-2 pl-4">
              <p className="font-serif font-medium">{example.source}</p>
              <p className="mt-1 text-muted-foreground">{example.target}</p>
            </div>
          ))}
        </div>
      </CardContent>
      <Separator />
      <CardFooter className="pt-4">
        <span className="text-sm text-muted-foreground underline underline-offset-2">
          Kiểm tra trên vi.wiktionary
        </span>
      </CardFooter>
    </Card>
  )
}

/**
 * L'écran « introuvable ». Il est sur la page d'accueil exprès : c'est la
 * promesse du produit, pas un cas limite qu'on cache.
 */
export function NotFoundSpecimen() {
  return (
    <Card className="w-full">
      <CardHeader>
        <CardTitle className="text-xl">
          Không tìm thấy <span className="font-serif">« embrouillamini »</span>
        </CardTitle>
      </CardHeader>
      <Separator />
      <CardContent>
        <p className="mb-3 text-sm text-muted-foreground">Có phải bạn muốn tìm:</p>
        <div className="flex flex-wrap gap-2">
          {['embrouiller', 'brouillamini', 'embrouille'].map((suggestion) => (
            <span
              key={suggestion}
              className="rounded-md border bg-background px-3 py-1.5 font-serif text-sm"
            >
              {suggestion}
            </span>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}
