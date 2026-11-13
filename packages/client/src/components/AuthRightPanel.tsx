import { useState, useEffect, useRef } from 'react'
import { motion } from 'framer-motion'

interface AuthRightPanelProps {
  variant: 'login' | 'signup'
}

const funFacts = [
  'Bạn có biết? Chữ « dictionary » đến từ tiếng Latin « dictionarium », nghĩa là « tập hợp các từ ».',
  'Bạn có biết? Từ dài nhất trong phần lớn từ điển tiếng Anh là « pneumonoultramicroscopicsilicovolcanoconiosis ».',
  'Bạn có biết? Shakespeare đặt ra hơn 1.700 từ mà đến giờ người ta vẫn dùng.',
  'Bạn có biết? Từ điển Oxford English Dictionary mất gần 50 năm mới ra xong ấn bản đầu tiên.',
  'Bạn có biết? « bookkeeper » là từ tiếng Anh duy nhất có ba cặp chữ đôi liền nhau.',
  'Bạn có biết? Học thêm một ngôn ngữ giúp trí nhớ và khả năng tập trung tốt lên.',
]

const languages = ['tiếng Pháp', 'tiếng Anh', 'tiếng Việt']

export function AuthRightPanel({ variant }: AuthRightPanelProps) {
  const [randomFact, setRandomFact] = useState('')
  const textRef = useRef<HTMLSpanElement>(null)

  const bgColorClass = variant === 'login'
    ? 'bg-linear-to-br from-amber-50 via-orange-50 to-yellow-50 dark:from-amber-950 dark:via-orange-950 dark:to-yellow-950'
    : 'bg-linear-to-br from-blue-50 via-indigo-50 to-purple-50 dark:from-blue-950 dark:via-indigo-950 dark:to-purple-950'

  useEffect(() => {
    setRandomFact(funFacts[Math.floor(Math.random() * funFacts.length)])
  }, [])

  useEffect(() => {
    if (!textRef.current) return

    const typewriterSequence = async () => {
      while (true) {
        for (let i = 0; i < languages.length; i++) {
          const text = languages[i]

          // Type out the text
          for (let j = 0; j <= text.length; j++) {
            if (textRef.current) {
              textRef.current.textContent = text.slice(0, j)
            }
            await new Promise(resolve => setTimeout(resolve, 80))
          }

          // Pause
          await new Promise(resolve => setTimeout(resolve, 1500))

          // Delete the text
          for (let j = text.length; j >= 0; j--) {
            if (textRef.current) {
              textRef.current.textContent = text.slice(0, j)
            }
            await new Promise(resolve => setTimeout(resolve, 50))
          }

          // Small pause before next word
          await new Promise(resolve => setTimeout(resolve, 300))
        }
      }
    }

    typewriterSequence()
  }, [])

  return (
    <motion.div
      className={`hidden lg:flex items-center justify-center ${bgColorClass} p-8`}
      initial={{ opacity: 0, x: 30 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.6, ease: 'easeOut' }}
    >
      <div className="max-w-md space-y-8">
        <div className="pb-50 space-y-4">
          <h2 className="text-4xl font-bold text-foreground">
            Từ điển của bạn
          </h2>
          <p className="text-lg text-muted-foreground">
            Giải nghĩa từ mới trong{' '}
            <span className="inline-block font-semibold text-primary min-w-[150px] text-left">
              <span ref={textRef}></span>
              <motion.span
                animate={{ opacity: [1, 0] }}
                transition={{ duration: 0.8, repeat: Infinity, repeatType: 'reverse' }}
                className="inline-block"
              >
                _
              </motion.span>
            </span>
          </p>
        </div>

        {/* Illustration Placeholder */}
        <div className="flex justify-center py-8">
          <motion.div
            className="relative"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.3, ease: 'easeOut' }}
          >
            <div className="text-6xl">🫎🫎</div>
          </motion.div>
        </div>

        {/* Fun Fact */}
        <motion.div
          className="rounded-lg bg-background/50 p-6 backdrop-blur-sm text-center"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.5, ease: 'easeOut' }}
        >
          <p className="text-sm text-muted-foreground italic">
            {randomFact}
          </p>
        </motion.div>
      </div>
    </motion.div>
  )
}
