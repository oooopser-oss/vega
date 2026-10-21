import type { Metadata } from "next";
import { Inter, Outfit } from "next/font/google";
import Script from "next/script";
import { siteConfig } from "@/config/site";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import { LeadModalProvider } from "@/components/LeadModalProvider";
import { JsonLd } from "@/components/JsonLd";
import { StickyMobileCta } from "@/components/StickyMobileCta";
import { reviews, getAverageRating } from "@/data/reviews";
import "./globals.css";

const inter = Inter({
  subsets: ["latin", "cyrillic"],
  variable: "--font-inter",
  display: "swap",
});

const outfit = Outfit({
  subsets: ["latin"],
  variable: "--font-outfit",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(siteConfig.url),
  title: {
    default: `${siteConfig.name} - ${siteConfig.slogan}`,
    template: `%s - ${siteConfig.name}`,
  },
  description: siteConfig.description,
  alternates: {
    canonical: "/",
  },
  openGraph: {
    title: `${siteConfig.name} - ${siteConfig.slogan}`,
    description: siteConfig.description,
    url: siteConfig.url,
    siteName: siteConfig.name,
    locale: "ru_RU",
    type: "website",
  },
  verification: {
    yandex: process.env.NEXT_PUBLIC_YANDEX_VERIFICATION,
    google: process.env.NEXT_PUBLIC_GOOGLE_VERIFICATION,
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const rating = getAverageRating();
  const yandexMetrikaId = process.env.NEXT_PUBLIC_YANDEX_METRIKA_ID;
  const gaId = process.env.NEXT_PUBLIC_GA_ID;

  return (
    <html lang="ru" className={`${inter.variable} ${outfit.variable}`}>
      <body className="flex min-h-dvh flex-col pb-[72px] sm:pb-0">
        <JsonLd
          data={{
            "@context": "https://schema.org",
            "@type": "HomeAndConstructionBusiness",
            name: siteConfig.name,
            legalName: siteConfig.legalName,
            description: siteConfig.description,
            url: siteConfig.url,
            telephone: siteConfig.contacts.phoneHref.replace("tel:", ""),
            email: siteConfig.contacts.email,
            address: {
              "@type": "PostalAddress",
              streetAddress: siteConfig.contacts.address,
              addressLocality: siteConfig.region.city,
              addressCountry: "RU",
            },
            areaServed: siteConfig.region.fullLabelPrepositional,
            priceRange: "от 47 000 ₽",
            sameAs: [siteConfig.social.vk, siteConfig.social.telegram],
            aggregateRating: {
              "@type": "AggregateRating",
              ratingValue: rating,
              reviewCount: reviews.length,
            },
          }}
        />

        {yandexMetrikaId && (
          <Script id="yandex-metrika" strategy="afterInteractive">
            {`
              (function(m,e,t,r,i,k,a){m[i]=m[i]||function(){(m[i].a=m[i].a||[]).push(arguments)};
              m[i].l=1*new Date();
              for (var j = 0; j < document.scripts.length; j++) {if (document.scripts[j].src === r) { return; }}
              k=e.createElement(t),a=e.getElementsByTagName(t)[0],k.async=1,k.src=r,a.parentNode.insertBefore(k,a)})
              (window, document, "script", "https://mc.yandex.ru/metrika/tag.js", "ym");
              ym(${yandexMetrikaId}, "init", { clickmap:true, trackLinks:true, accurateTrackBounce:true, webvisor:true });
            `}
          </Script>
        )}

        {gaId && (
          <>
            <Script src={`https://www.googletagmanager.com/gtag/js?id=${gaId}`} strategy="afterInteractive" />
            <Script id="ga-init" strategy="afterInteractive">
              {`
                window.dataLayer = window.dataLayer || [];
                function gtag(){dataLayer.push(arguments);}
                gtag('js', new Date());
                gtag('config', '${gaId}');
              `}
            </Script>
          </>
        )}

        <LeadModalProvider>
          <Header />
          <main className="flex-1">{children}</main>
          <Footer />
          <StickyMobileCta />
        </LeadModalProvider>
      </body>
    </html>
  );
}
