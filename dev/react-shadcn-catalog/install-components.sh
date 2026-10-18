#!/bin/bash
# Install all remaining shadcn components

cd "$(dirname "$0")"

echo "Installing Priority 4 (Complex) components..."
npx shadcn@latest add command --yes
npx shadcn@latest add calendar --yes
npx shadcn@latest add carousel --yes
npx shadcn@latest add navigation-menu --yes

echo "Installing remaining components (batch 1)..."
npx shadcn@latest add accordion --yes
npx shadcn@latest add alert --yes
npx shadcn@latest add alert-dialog --yes
npx shadcn@latest add aspect-ratio --yes
npx shadcn@latest add avatar --yes
npx shadcn@latest add breadcrumb --yes

echo "Installing remaining components (batch 2)..."
npx shadcn@latest add collapsible --yes
npx shadcn@latest add context-menu --yes
npx shadcn@latest add hover-card --yes
npx shadcn@latest add menubar --yes
npx shadcn@latest add pagination --yes
npx shadcn@latest add progress --yes

echo "Installing remaining components (batch 3)..."
npx shadcn@latest add radio --yes
npx shadcn@latest add resizable --yes
npx shadcn@latest add scroll-area --yes
npx shadcn@latest add skeleton --yes
npx shadcn@latest add slider --yes
npx shadcn@latest add sonner --yes

echo "Installing remaining components (batch 4)..."
npx shadcn@latest add table --yes
npx shadcn@latest add tabs --yes
npx shadcn@latest add toggle --yes
npx shadcn@latest add toggle-group --yes

echo "Installation complete!"
ls -1 src/components/ui/ | wc -l
echo "Total components installed"
