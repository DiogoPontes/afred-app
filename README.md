# Alfred

O **Alfred** é um aplicativo de organização pessoal desenvolvido com Flutter. Ele reúne diferentes áreas do dia a dia em um só lugar, com uma interface em português.

## Funcionalidades

- **Tarefas:** registre e acompanhe suas tarefas.
- **Finanças:** organize lançamentos financeiros e acompanhe eventos relacionados a eles.
- **Atividade Física:** registre atividades e acompanhe informações das sessões.
- **Compras:** mantenha listas de compras.
- **Estudos:** organize disciplinas e sessões de estudo.
- **Leitura:** registre livros e atividades de leitura.
- **Foco e anotações:** use recursos de apoio à organização da rotina.

Os dados do aplicativo são armazenados localmente com **Hive**. O projeto também utiliza **Supabase** para autenticação e sincronização de dados.

## Tecnologias

- [Flutter](https://flutter.dev/) — desenvolvimento da interface e do aplicativo.
- [Dart](https://dart.dev/) — linguagem utilizada pelo Flutter.
- [Hive](https://pub.dev/packages/hive) — armazenamento local.
- [Supabase](https://supabase.com/) — autenticação e serviços de backend.

## Como executar o projeto

### Pré-requisitos

Instale o Flutter e configure pelo menos um dispositivo ou emulador. Para verificar a instalação, execute:

```bash
flutter doctor
```

### Baixar as dependências

Na pasta do projeto, execute:

```bash
flutter pub get
```

### Iniciar o aplicativo

Para executar no dispositivo ou emulador padrão:

```bash
flutter run
```

Para executar no Chrome:

```bash
flutter run -d chrome
```

## Estrutura do projeto

- `lib/screens/` — telas do aplicativo.
- `lib/widgets/` — componentes reutilizáveis, incluindo formulários.
- `lib/services/` — serviços de armazenamento, sincronização e outras regras do aplicativo.
- `assets/` — recursos utilizados pelo projeto.

## Configuração do Supabase

O aplicativo utiliza o Supabase para autenticação e sincronização. Para executar uma cópia do projeto, configure um projeto Supabase e verifique os parâmetros de conexão usados pelo aplicativo.

Não coloque chaves secretas ou credenciais administrativas no repositório. Chaves privadas, como `service_role` ou `sb_secret`, devem permanecer fora do aplicativo e do GitHub.

## Contribuição

1. Crie uma cópia (*fork*) do repositório.
2. Faça uma branch para suas alterações.
3. Teste as mudanças localmente.
4. Envie um *pull request* com uma descrição do que foi alterado.

## Sobre o Flutter

Se você está começando com Flutter, consulte a [documentação oficial](https://docs.flutter.dev/), que inclui guias, tutoriais e referências da API.
