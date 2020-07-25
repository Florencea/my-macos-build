# Git Note

## Using commit template

- Create `.gitmessage.txt`
- Using commit template under project directory.

  - `git config commit.template .gitmessage.txt`

- Using commit template in system scope.

  - `git config --global commit.template ~/.gitmessage.txt`

## Using Git commit rules

- Structure

  - `<type>(<scope>): <subject>`

- `type`

  - Describe commit type, only 7 types below are allowed.
    - `feat`: New features.
    - `fix`: Bug fix.
    - `docs`: Documentation.
    - `style`: Code style(no functional change).
    - `refactor`: Refactoring(no new feature, no functional change).
    - `test`: Add tests.
    - `chore`: Change for developing enviroment.

- `scope`

  - Scope affected by this commit, can be file or abstract layers.

- `subject`

  - What the commit do, less than 50 words.
  - Start by a lowercased, first person present tense verb.
  - No dot(.) at end.
