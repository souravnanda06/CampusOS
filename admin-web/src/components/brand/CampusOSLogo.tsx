import * as React from "react"
import { cn } from "@/lib/utils"

export type CampusOSLogoVariant =
  | "primary"
  | "accent"
  | "monochrome"
  | "reversed"
  | "mark"

export interface CampusOSLogoProps extends React.ImgHTMLAttributes<HTMLImageElement> {
  variant?: CampusOSLogoVariant
  className?: string
  alt?: string
}

const LOGO_ASSETS: Record<CampusOSLogoVariant, { src: string; defaultAlt: string; aspectRatio: string }> = {
  primary: {
    src: "/branding/campusos-wordmark-primary.svg",
    defaultAlt: "CampusOS Logo",
    aspectRatio: "883 / 157",
  },
  accent: {
    src: "/branding/campusos-wordmark-accent.svg",
    defaultAlt: "CampusOS Logo",
    aspectRatio: "883 / 156",
  },
  monochrome: {
    src: "/branding/campusos-wordmark-monochrome.svg",
    defaultAlt: "CampusOS Logo",
    aspectRatio: "883 / 157",
  },
  reversed: {
    src: "/branding/campusos-wordmark-reversed.svg",
    defaultAlt: "CampusOS Logo",
    aspectRatio: "883 / 157",
  },
  mark: {
    src: "/branding/campusos-mark.svg",
    defaultAlt: "CampusOS Mark",
    aspectRatio: "1 / 1",
  },
}

export const CampusOSLogo = React.forwardRef<HTMLImageElement, CampusOSLogoProps>(
  ({ variant = "primary", className, alt, style, ...props }, ref) => {
    const config = LOGO_ASSETS[variant] || LOGO_ASSETS.primary

    return (
      <img
        ref={ref}
        src={config.src}
        alt={alt ?? config.defaultAlt}
        className={cn("select-none object-contain transition-opacity", className)}
        style={{
          aspectRatio: config.aspectRatio,
          ...style,
        }}
        loading="eager"
        decoding="async"
        {...props}
      />
    )
  }
)

CampusOSLogo.displayName = "CampusOSLogo"
