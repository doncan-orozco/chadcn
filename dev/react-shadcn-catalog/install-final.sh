#!/bin/bash
cd /Users/doncan/Documents/papyro/react-shadcn-catalog

echo "Installing final components..."
npx shadcn@latest add aspect-ratio --yes
sleep 5
npx shadcn@latest add scroll-area --yes
sleep 5
npx shadcn@latest add sonner --yes
sleep 5
npx shadcn@latest add toggle-group --yes
sleep 5
npx shadcn@latest add command --yes

echo "Final installation complete!"
ls -1 src/components/ui/ | wc -l
