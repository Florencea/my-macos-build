# React Development Notes

## Create React APP + TypeScript + Google TypeScript Style + SASS

```fish
npx create-react-app app-name --template typescript
cd app-name
npm install bootstrap reactstrap node-sass@4.14.1
npx gts init
```

- Remove `typescript` and `@types/node` devDependencies. (important!)

- Add `custom.scss` to `src/` and import bootstrap css at last line.

  ```css
  @import "../node_modules/bootstrap/scss/bootstrap";
  ```

- Clear `App.tsx` and `App.css`, start codeing.
