# CapacityHub · Squad Map Oven AI

Controle de alocação de recursos por fundo de investimento (PD Law, Empresa, Embrapii), mês a mês, com previsto, planejado e realizado. Página estática (um `index.html`) + Supabase para login, recuperação de senha por e-mail, banco de dados e níveis de acesso.

```
index.html            ← o sistema inteiro (HTML/CSS/JS)
config.js             ← URL e chave pública do seu projeto Supabase (único arquivo a editar)
supabase/schema.sql   ← tabelas, regras de acesso (RLS), trigger de perfil, tempo real
supabase/seed.sql     ← dados iniciais (pessoas, alocações, valores) exportados do Squad Map
```

## Colocar no ar (15 minutos)

### 1. Criar o projeto no Supabase

1. Acesse <https://supabase.com>, crie uma conta e clique em **New project** (plano Free atende).
2. Escolha nome, senha do banco e região (`South America (São Paulo)`).
3. Com o projeto criado, vá em **Project Settings → API** e copie:
   - **Project URL** (algo como `https://abcd1234.supabase.co`)
   - **anon public** key (chave longa que começa com `eyJ…`)

### 2. Criar as tabelas e regras

1. No menu lateral, **SQL Editor → New query**.
2. Cole o conteúdo de `supabase/schema.sql` e clique em **Run**.
3. Nova query: cole `supabase/seed.sql` e **Run** (carrega as 13 pessoas, alocações e valores atuais).

### 3. Configurar o login por e-mail

Em **Authentication → URL Configuration**:

- **Site URL**: o endereço onde a página vai rodar, por exemplo `https://paulomessias1.github.io/CapacityHub/`
- **Redirect URLs**: o mesmo endereço (é para onde o link de "esqueci minha senha" volta).

Em **Authentication → Providers → Email**, deixe **Email** habilitado. Por padrão o Supabase pede confirmação do e-mail ao criar conta; para pular isso em testes, desligue **Confirm email**.

> O envio de e-mails (confirmação e redefinição de senha) usa o serviço embutido do Supabase, limitado a poucos e-mails por hora. Para uso contínuo do time, configure um SMTP próprio em **Project Settings → Auth → SMTP Settings** (Gmail, Outlook, Resend, etc.).

### 4. Apontar a página para o projeto

Edite `config.js`:

```js
window.CAPACITY_CONFIG = {
  SUPABASE_URL: "https://abcd1234.supabase.co",
  SUPABASE_ANON_KEY: "eyJ..."
};
```

A chave *anon* é pública por desenho; quem protege os dados são as regras de acesso do banco (RLS), já criadas pelo `schema.sql`.

### 5. Publicar no GitHub Pages

No repositório: **Settings → Pages → Build and deployment → Source: Deploy from a branch → Branch: `main` / `(root)` → Save**. Em um ou dois minutos a página estará em `https://paulomessias1.github.io/CapacityHub/`.

### 6. Primeira conta = administrador

Abra a página, clique em **Criar conta** e cadastre-se. **A primeira conta criada no sistema vira Administrador automaticamente**; todas as seguintes entram como Leitura até um administrador alterar o nível na aba **Usuários**.

## Níveis de acesso

| Nível | O que pode fazer |
|---|---|
| **Administrador** | Tudo: pessoas, fundos, orçamento, período, alocações, valores, níveis de acesso |
| **Editor** | Alocações, valores por fundo no rodapé, previsto e realizado |
| **Leitura** | Vê tudo, não altera nada |

As regras são aplicadas no servidor (RLS do Postgres), não apenas na tela.

## Como o sistema calcula

- **Planejado** = Σ (custo integral × fração no fundo) de cada pessoa ativa, por mês. A linha de cada fundo no rodapé da grade pode ser sobrescrita à mão (valor vindo de outra planilha); digite `=` na célula para voltar ao cálculo.
- **Previsto** = orçamento mensal esperado por fundo, digitado no Resumo ou gerado por "Congelar planejado como previsto".
- **Realizado** = valor pago no mês, copiado da planilha de cashflow do financeiro.
- **Projeção de fechamento** = realizado nos meses lançados + planejado nos demais.

## Rodar localmente

Qualquer servidor estático serve; por exemplo:

```bash
python3 -m http.server 8080
# abra http://localhost:8080
```

Adicione `http://localhost:8080` em **Redirect URLs** no Supabase se quiser testar a recuperação de senha localmente.
