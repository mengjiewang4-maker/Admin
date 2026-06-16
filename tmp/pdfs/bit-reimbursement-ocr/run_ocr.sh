#!/usr/bin/env bash
set -euo pipefail

PDF="raw/BIT财务报销指南.pdf"
WORK="tmp/pdfs/bit-reimbursement-ocr"
PAGES="$WORK/pages"
TEXT="$WORK/text"
OUT="output/pdf/BIT财务报销指南-OCR.md"
DPI="${DPI:-200}"
LANG="${LANGUAGE_MODEL:-chi_sim+eng}"

mkdir -p "$PAGES" "$TEXT" "$(dirname "$OUT")" "$WORK/swift-module-cache"

swift -module-cache-path "$WORK/swift-module-cache" \
  "$WORK/render_pdf_pages.swift" "$PDF" "$PAGES" "$DPI"

for image in "$PAGES"/page-*.png; do
  base="$(basename "$image" .png)"
  txt="$TEXT/$base.txt"
  if [[ -s "$txt" ]]; then
    echo "skip $base"
    continue
  fi
  echo "ocr $base"
  tesseract "$image" "$TEXT/$base" -l "$LANG" --psm 6 txt
done

{
  printf -- "---\n"
  printf -- "title: BIT财务报销指南 OCR\n"
  printf -- "source: raw/BIT财务报销指南.pdf\n"
  printf -- "pages: 177\n"
  printf -- "ocr_engine: tesseract\n"
  printf -- "ocr_language: %s\n" "$LANG"
  printf -- "tags:\n"
  printf -- "  - 报销\n"
  printf -- "  - 财务\n"
  printf -- "  - OCR\n"
  printf -- "---\n\n"
  printf -- "# BIT财务报销指南 OCR\n\n"
  printf -- "> [!note]\n"
  printf -- "> 本文由 OCR 自动识别生成。OCR 即“图片文字识别”，扫描件可能存在错字、漏字或表格错位，关键金额、日期、流程要求请以原 PDF 为准。\n\n"
  printf -- "原文件：![[BIT财务报销指南.pdf]]\n\n"

  for txt in "$TEXT"/page-*.txt; do
    page="$(basename "$txt" .txt | sed 's/page-//; s/^0*//')"
    printf -- "\n## 第 %s 页\n\n" "$page"
    sed '/^[[:space:]]*$/N;/^\n$/D' "$txt"
    printf -- "\n"
  done
} > "$OUT"

echo "$OUT"
