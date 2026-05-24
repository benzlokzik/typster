const tailwindAtRules = [
  "apply",
  "config",
  "custom-variant",
  "layer",
  "plugin",
  "reference",
  "responsive",
  "screen",
  "source",
  "tailwind",
  "theme",
  "utility",
  "variant",
  "variants",
];

export default {
  extends: ["stylelint-config-standard"],
  plugins: ["stylelint-order"],

  ignoreFiles: [
    "node_modules/**",
    "../priv/static/**",
    "../preview-export/**",
    "vendor/**",
    "**/*.min.css",
  ],

  reportInvalidScopeDisables: true,
  reportNeedlessDisables: true,

  rules: {
    "at-rule-no-unknown": [true, { ignoreAtRules: tailwindAtRules }],

    "length-zero-no-unit": true,
    "shorthand-property-no-redundant-values": true,

    "declaration-block-no-duplicate-properties": [
      true,
      { ignore: ["consecutive-duplicates-with-different-values"] },
    ],
    "selector-max-id": 1,

    "property-no-vendor-prefix": [
      true,
      {
        ignoreProperties: [
          "appearance",
          "-webkit-appearance",
          "backdrop-filter",
          "-webkit-backdrop-filter",
          "mask-image",
          "-webkit-mask-image",
        ],
      },
    ],
    "value-no-vendor-prefix": true,

    "alpha-value-notation": null,
    "at-rule-empty-line-before": null,
    "color-function-alias-notation": null,
    "color-function-notation": null,
    "color-hex-length": null,
    "comment-empty-line-before": null,
    "custom-property-empty-line-before": null,
    "custom-property-pattern": null,
    "declaration-block-single-line-max-declarations": null,
    "declaration-empty-line-before": null,
    "font-family-name-quotes": null,
    "function-url-quotes": null,
    "hue-degree-notation": null,
    "import-notation": null,
    "keyframes-name-pattern": null,
    "media-feature-range-notation": null,
    "no-descending-specificity": null,
    "no-duplicate-selectors": null,
    "no-invalid-position-at-import-rule": null,
    "number-max-precision": null,
    "order/order": null,
    "rule-empty-line-before": null,
    "selector-class-pattern": null,
    "selector-id-pattern": null,
    "value-keyword-case": null,
  },
};
