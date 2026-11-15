# JT-FIT
Sistema de consultoria fitness: painel da personal, alunas, biblioteca de exercícios, modelos de treino e links individuais.

## Segurança
- Banco Supabase com RLS em todas as tabelas privadas.
- Links usam token aleatório de 256 bits; somente SHA-256 é armazenado.
- Edge Function verifica expiração e revogação no servidor antes de entregar o treino.
- A chave publishable no frontend é pública por definição; nunca publicar secret/service role.

O frontend é publicado via GitHub Pages. O backend usa Supabase Auth, Postgres e Edge Functions.