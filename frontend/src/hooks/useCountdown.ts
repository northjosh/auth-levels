import { useState, useEffect, useCallback } from "react";

interface CountdownOptions {
  initialTime: number; // in seconds
  onComplete?: () => void;
  onTick?: (timeLeft: number) => void;
}

interface CountdownReturn {
  timeLeft: number;
  isRunning: boolean;
  isExpired: boolean;
  start: () => void;
  pause: () => void;
  reset: () => void;
  formatTime: (seconds: number) => string;
}

export const useCountdown = (options: CountdownOptions): CountdownReturn => {
  const { initialTime, onComplete, onTick } = options;
  const [timeLeft, setTimeLeft] = useState(initialTime);
  const [isRunning, setIsRunning] = useState(false);

  const formatTime = useCallback((seconds: number): string => {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes.toString().padStart(2, "0")}:${remainingSeconds
      .toString()
      .padStart(2, "0")}`;
  }, []);

  const start = useCallback(() => {
    setIsRunning(true);
  }, []);

  const pause = useCallback(() => {
    setIsRunning(false);
  }, []);

  const reset = useCallback(() => {
    setTimeLeft(initialTime);
    setIsRunning(false);
  }, [initialTime]);

  useEffect(() => {
    let interval: NodeJS.Timeout | null = null;

    if (isRunning && timeLeft > 0) {
      interval = setInterval(() => {
        setTimeLeft((prevTime) => {
          const newTime = prevTime - 1;
          onTick?.(newTime);

          if (newTime <= 0) {
            setIsRunning(false);
            onComplete?.();
            return 0;
          }

          return newTime;
        });
      }, 1000);
    }

    return () => {
      if (interval) {
        clearInterval(interval);
      }
    };
  }, [isRunning, timeLeft, onComplete, onTick]);

  
  useEffect(() => {
    start();
  }, [start]);

  return {
    timeLeft,
    isRunning,
    isExpired: timeLeft === 0,
    start,
    pause,
    reset,
    formatTime,
  };
};
