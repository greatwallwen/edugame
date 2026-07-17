/** CSS Modules 类型声明，让 TypeScript 认识 *.module.css */
declare module '*.module.css' {
  const classes: Record<string, string>;
  export default classes;
}
