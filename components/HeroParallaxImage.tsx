"use client";

import { useRef } from "react";
import Image from "next/image";
import {
  motion,
  useScroll,
  useTransform,
  useMotionTemplate,
  useReducedMotion,
} from "motion/react";

export function HeroParallaxImage() {
  const ref = useRef<HTMLDivElement>(null);
  const reduce = useReducedMotion();

  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start start", "end start"],
  });

  const y = useTransform(scrollYProgress, [0, 1], [0, 48]);
  const scale = useTransform(scrollYProgress, [0, 1], [1, 1.08]);
  const transform = useMotionTemplate`translateY(${y}px) scale(${scale})`;

  return (
    <div ref={ref} className="relative aspect-[4/3] w-full overflow-hidden rounded-card lg:aspect-[5/4]">
      <motion.div className="absolute inset-0" style={reduce ? undefined : { transform }}>
        <Image
          src="/images/hero-house.jpg"
          alt="Частный дом с установленной станцией очистки на участке"
          fill
          priority
          sizes="(min-width: 1024px) 45vw, 100vw"
          className="object-cover"
        />
      </motion.div>
    </div>
  );
}
