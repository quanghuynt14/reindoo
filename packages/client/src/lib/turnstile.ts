import { useEffect, useState, useCallback, useRef } from 'react';

declare global {
  interface Window {
    turnstile: {
      render: (container: string, options: TurnstileOptions) => string;
      reset: (container: string) => void;
    };
  }
}

interface TurnstileOptions {
  sitekey: string;
  callback: (token: string) => void;
  'error-callback'?: () => void;
  'expired-callback'?: () => void;
  theme?: 'light' | 'dark' | 'auto';
  size?: 'normal' | 'compact';
}

export function useTurnstile(containerId: string) {
  const [token, setToken] = useState('');
  const [widgetReady, setWidgetReady] = useState(false);
  const widgetIdRef = useRef<string | null>(null);
  const siteKey = import.meta.env.VITE_TURNSTILE_SITE_KEY as string;

  const renderWidget = useCallback(() => {
    if (!siteKey || !window.turnstile) return;

    const container = document.getElementById(containerId);
    if (!container) return;

    widgetIdRef.current = window.turnstile.render(`#${containerId}`, {
      sitekey: siteKey,
      callback: (newToken: string) => {
        setToken(newToken);
      },
      'error-callback': () => {
        setToken('');
      },
      'expired-callback': () => {
        setToken('');
      },
      theme: 'auto',
    });
    setWidgetReady(true);
  }, [containerId, siteKey]);

  useEffect(() => {
    if (!siteKey) return;

    if (window.turnstile) {
      renderWidget();
      return;
    }

    const existing = document.querySelector(
      'script[src="https://challenges.cloudflare.com/turnstile/v0/api.js"]',
    );
    if (existing) {
      existing.addEventListener('load', renderWidget, { once: true });
      return;
    }

    const script = document.createElement('script');
    script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js';
    script.async = true;
    script.defer = true;
    script.onload = renderWidget;
    document.head.appendChild(script);
  }, [siteKey, renderWidget]);

  const resetTurnstile = useCallback(() => {
    setToken('');
    if (window.turnstile && widgetIdRef.current) {
      window.turnstile.reset(`#${containerId}`);
    }
  }, [containerId]);

  const isConfigured = Boolean(siteKey);

  return { token, widgetReady, resetTurnstile, isConfigured };
}
