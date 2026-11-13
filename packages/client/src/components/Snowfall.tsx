import { useEffect, useState, useRef } from 'react';

/**
 * Snowfall Component
 * 
 * A lightweight CSS-based snowfall animation effect that complements the Northern Lights background.
 * Features:
 * - Dynamic snowflakes (20 by default, up to 60 when shaken)
 * - GPU-accelerated CSS transforms for optimal performance
 * - Respects prefers-reduced-motion for accessibility
 * - Shake-to-increase-snow on mobile devices
 */

const INITIAL_SNOWFLAKE_COUNT = 20;
// High z-index to ensure debug feedback appears above all UI elements including modals
const DEBUG_FEEDBACK_Z_INDEX = 9999;

export function Snowfall() {
  const [snowflakeCount, setSnowflakeCount] = useState(INITIAL_SNOWFLAKE_COUNT);
  const [isShaking, setIsShaking] = useState(false);
  
  // Use refs to persist values across re-renders
  const lastX = useRef(0);
  const lastY = useRef(0);
  const lastZ = useRef(0);
  const lastUpdate = useRef(0);
  const timeoutIds = useRef<NodeJS.Timeout[]>([]);
  const isShakingRef = useRef(false);
  const listenerAddedRef = useRef(false);
  const snowflakeIdsRef = useRef<number[]>(Array.from({ length: INITIAL_SNOWFLAKE_COUNT }, (_, i) => i));
  const nextIdRef = useRef(INITIAL_SNOWFLAKE_COUNT);

  useEffect(() => {
    // Check if DeviceMotionEvent is available (mobile device)
    if (typeof window === 'undefined' || !window.DeviceMotionEvent) {
      return;
    }

    const SHAKE_THRESHOLD = 15; // Acceleration threshold for shake detection
    const SNOWFALL_DURATION = 5000; // Duration of increased snowfall
    const MAX_SNOWFLAKES = 60; // Reduced from 100 for better performance on mobile

    const handleMotion = (event: DeviceMotionEvent) => {
      const current = Date.now();
      const timeDiff = current - lastUpdate.current;

      if (timeDiff < 100) return; // Throttle events

      const acceleration = event.accelerationIncludingGravity;
      if (!acceleration || acceleration.x === null || acceleration.y === null || acceleration.z === null) {
        return;
      }

      const { x, y, z } = acceleration;
      
      if (lastUpdate.current !== 0) {
        const deltaX = Math.abs(x - lastX.current);
        const deltaY = Math.abs(y - lastY.current);
        const deltaZ = Math.abs(z - lastZ.current);

        // Detect shake: significant movement on multiple axes
        if ((deltaX > SHAKE_THRESHOLD || deltaY > SHAKE_THRESHOLD || deltaZ > SHAKE_THRESHOLD) && !isShakingRef.current) {
          isShakingRef.current = true;
          
          // Immediately increase snowflake count and show debug feedback
          setSnowflakeCount(MAX_SNOWFLAKES);
          setIsShaking(true);

          // Clean up any existing timeout
          timeoutIds.current.forEach(clearTimeout);
          timeoutIds.current = [];

          // Reset to normal after duration and clear shake flag
          const timeout = setTimeout(() => {
            setSnowflakeCount(INITIAL_SNOWFLAKE_COUNT);
            setIsShaking(false);
            isShakingRef.current = false;
          }, SNOWFALL_DURATION);
          timeoutIds.current.push(timeout);
        }
      }

      lastX.current = x;
      lastY.current = y;
      lastZ.current = z;
      lastUpdate.current = current;
    };

    // Request permission for iOS 13+ devices
    const requestPermission = async () => {
      if (typeof (DeviceMotionEvent as any).requestPermission === 'function') {
        try {
          const permission = await (DeviceMotionEvent as any).requestPermission();
          if (permission === 'granted') {
            window.addEventListener('devicemotion', handleMotion);
            listenerAddedRef.current = true;
          }
        } catch (error) {
          // Permission denied or error - silently ignore
        }
      } else {
        // For non-iOS 13+ devices, just add the listener
        window.addEventListener('devicemotion', handleMotion);
        listenerAddedRef.current = true;
      }
    };

    (async () => {
      await requestPermission();
    })();

    return () => {
      // Only remove listener if it was actually added
      if (listenerAddedRef.current) {
        window.removeEventListener('devicemotion', handleMotion);
        listenerAddedRef.current = false;
      }
      // Clean up any pending timeouts
      timeoutIds.current.forEach(clearTimeout);
      timeoutIds.current = [];
    };
  }, []); // Remove isShaking from dependencies to avoid stale closure

  // Generate stable IDs for snowflakes to avoid rendering issues
  useEffect(() => {
    const currentIds = snowflakeIdsRef.current;
    const diff = snowflakeCount - currentIds.length;
    
    if (diff > 0) {
      // Add new snowflakes with unique IDs
      for (let i = 0; i < diff; i++) {
        currentIds.push(nextIdRef.current++);
      }
    } else if (diff < 0) {
      // Remove snowflakes from the end
      currentIds.splice(snowflakeCount);
    }
    
    snowflakeIdsRef.current = [...currentIds];
  }, [snowflakeCount]);

  return (
    <>
      <div className="snowfall-container" aria-hidden="true">
        {snowflakeIdsRef.current.map((id) => (
          <div key={id} className="snowflake">❄</div>
        ))}
      </div>
      {isShaking && (
        <div
          className="shake-debug-feedback"
          style={{ zIndex: DEBUG_FEEDBACK_Z_INDEX }}
        >
          Shaking...
        </div>
      )}
    </>
  );
}
