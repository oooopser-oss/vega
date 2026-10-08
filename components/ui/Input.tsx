import { InputHTMLAttributes, forwardRef } from "react";

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { label, error, id, className = "", ...props },
  ref
) {
  return (
    <div>
      {label && (
        <label htmlFor={id} className="field-label">
          {label}
          {props.required && <span className="text-brand-700"> *</span>}
        </label>
      )}
      <input
        ref={ref}
        id={id}
        className={`field-input ${error ? "border-red-400 focus:border-red-500 focus:ring-red-500/20" : ""} ${className}`}
        {...props}
      />
      {error && <p className="mt-1.5 text-sm text-red-600">{error}</p>}
    </div>
  );
});
