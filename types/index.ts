export type ProductType = "Накопительный септик" | "Станция глубокой очистки";

export interface ProductSpec {
  users: number;
  performance: number;
  volume: number;
  dimensions: string;
  power?: string;
}

export interface ProductImage {
  id: string;
  alt: string;
}

export interface Product {
  slug: string;
  brand: string;
  name: string;
  type: ProductType;
  shortDescription: string;
  description: string;
  spec: ProductSpec;
  price: number;
  oldPrice?: number;
  isBestseller?: boolean;
  isNew?: boolean;
  images: ProductImage[];
  features: string[];
}

export interface ServiceItem {
  slug: string;
  icon: string;
  title: string;
  shortDescription: string;
  description: string;
  priceFrom?: number;
  steps?: string[];
}

export interface PortfolioItem {
  slug: string;
  title: string;
  city: string;
  productBrand: string;
  durationDays: number;
  description: string;
  imageId: string;
}

export interface Review {
  id: string;
  name: string;
  city: string;
  rating: number;
  date: string;
  text: string;
  productBrand?: string;
}

export interface FaqItem {
  question: string;
  answer: string;
}

export interface Region {
  slug: string;
  city: string;
  fullLabel: string;
  fullLabelPrepositional: string;
  districtNote: string;
}

export interface PriceRow {
  name: string;
  priceFrom: number;
  unit: string;
}

export interface LeadFormPayload {
  formType: "call" | "estimate" | "select" | "product" | "installation";
  name: string;
  phone: string;
  district?: string;
  comment?: string;
  residents?: string;
  usageMode?: string;
  productSlug?: string;
  source?: string;
  companyWebsite?: string;
}
