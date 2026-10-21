import { MetadataRoute } from "next";
import { siteConfig } from "@/config/site";
import { products } from "@/data/products";
import { regions } from "@/data/regions";

export default function sitemap(): MetadataRoute.Sitemap {
  const staticPages = [
    "",
    "/catalog",
    "/installation",
    "/services",
    "/prices",
    "/portfolio",
    "/reviews",
    "/about",
    "/offers",
    "/contacts",
  ];

  const entries: MetadataRoute.Sitemap = staticPages.map((path) => ({
    url: `${siteConfig.url}${path}`,
    lastModified: new Date(),
  }));

  products.forEach((p) => {
    entries.push({ url: `${siteConfig.url}/catalog/${p.slug}`, lastModified: new Date() });
  });

  regions.forEach((r) => {
    entries.push({ url: `${siteConfig.url}/${r.slug}`, lastModified: new Date() });
  });

  return entries;
}
