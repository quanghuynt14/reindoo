import { motion } from 'framer-motion'
import { useState } from 'react'

type Side = 'left' | 'right'

const START_LEFT = '25%'
const END_LEFT = '75%'
const RUN_DURATION = 1.2
const ARC_HEIGHT = 90
const TURN_DURATION = 0.2

// Le glyphe 🦌 regarde vers la **gauche** de lui-même. Donc scaleX: 1 le laisse
// tourné à gauche, et un renne qui court vers la droite le faisait à reculons.
// On multiplie par ce facteur pour que `facing` veuille dire la direction de la
// course — +1 vers la droite — et non la valeur brute de scaleX.
const GLYPH_FACES_LEFT = -1

export function Reindeer() {
  const [side, setSide] = useState<Side>('left')
  const [hasMoved, setHasMoved] = useState(false)
  const toggle = () => {
    setHasMoved(true)
    setSide((s) => (s === 'left' ? 'right' : 'left'))
  }

  return (
    <div className="pointer-events-none fixed inset-0 z-20">
      <ReindeerSprite
        side={side}
        hasMoved={hasMoved}
        runDelay={0}
        bobOffset={0}
        onClick={toggle}
        top="65%"
        index={1}
      />
      <ReindeerSprite
        side={side}
        hasMoved={hasMoved}
        runDelay={0.15}
        bobOffset={0.3}
        onClick={toggle}
        top="75%"
        index={2}
      />
    </div>
  )
}

function ReindeerSprite({
  side,
  hasMoved,
  runDelay,
  bobOffset,
  onClick,
  top,
  index,
}: {
  side: Side
  hasMoved: boolean
  runDelay: number
  bobOffset: number
  onClick: () => void
  top: string
  index: number
}) {
  // `facing` is independent of `side` — it carries the direction the reindeer
  // is ready to run next: +1 to the right, -1 to the left. The reindeer runs
  // forward in the direction it's already facing, then turns around after
  // arrival to prep for the next trip. Default +1 so the first click sends it
  // to the right edge.
  //
  // C'est une direction de course, pas un scaleX : le glyphe est retourné par
  // GLYPH_FACES_LEFT au moment de l'appliquer.
  const [facing, setFacing] = useState(1)
  const targetLeft = side === 'left' ? START_LEFT : END_LEFT

  // Horizontal travel uses a tween (not spring) so its duration can be matched
  // by the arc layer below — otherwise the apex won't line up with the midpoint.
  return (
    <motion.button
      type="button"
      onClick={onClick}
      aria-label={`reindeer ${index}`}
      className="pointer-events-auto absolute -translate-x-1/2 -translate-y-1/2 cursor-pointer select-none border-0 bg-transparent p-0"
      style={{ top }}
      initial={false}
      animate={{ left: targetLeft }}
      transition={{
        duration: RUN_DURATION,
        ease: 'easeInOut',
        delay: runDelay,
      }}
      onAnimationComplete={() => {
        if (!hasMoved) return
        // Just arrived — turn around to face the next trip's direction.
        setFacing(side === 'right' ? -1 : 1)
      }}
    >
      {/* Idle bob + facing direction. Wraps the arc layer so the bob loop
          survives the per-click remount of the arc element (keyed on `side`). */}
      <motion.div
        animate={{ y: [0, -6, 0], scaleX: facing * GLYPH_FACES_LEFT }}
        transition={{
          y: {
            duration: 0.6,
            repeat: Infinity,
            ease: 'easeInOut',
            delay: bobOffset,
          },
          scaleX: { duration: TURN_DURATION, ease: 'easeOut' },
        }}
      >
        <motion.div
          key={side}
          initial={{ y: 0 }}
          animate={hasMoved ? { y: [0, -ARC_HEIGHT, 0] } : { y: 0 }}
          transition={{
            duration: RUN_DURATION,
            ease: 'easeInOut',
            delay: runDelay,
          }}
          className="text-5xl drop-shadow-[0_2px_4px_rgba(0,0,0,0.5)] sm:text-6xl dark:drop-shadow-[0_2px_6px_rgba(255,255,255,0.35)]"
        >
          🦌
        </motion.div>
      </motion.div>
    </motion.button>
  )
}
