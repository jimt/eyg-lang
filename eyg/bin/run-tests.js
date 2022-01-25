import assert from "assert";
import { opendir } from "fs/promises";
const dir = "gen/javascript/eyg/";
import fs from 'fs';

async function main() {
  console.log("Running tests...");
  let saved = await import("../../editor/public/saved.json")

  let passes = 0;
  let failures = 0;

  for await (let entry of await opendir(dir)) {
    if (!entry.name.endsWith("test.js")) continue;
    let path = "../" + dir + entry.name;
    process.stdout.write("\nlanguage/" + entry.name.slice(0, -3) + ":\n  ");
    let module = await import(path);

    for (let fnName of Object.keys(module)) {
      if (!fnName.endsWith("_test")) continue;
      try {
        module[fnName](saved.default);
        process.stdout.write("✨");
        passes++;
      } catch (error) {
        process.stdout.write(`❌ ${fnName}: ${JSON.stringify(error)}\n${error.stack}\n  `);
        failures++;
      }
    }
  }

  console.log(`
${passes + failures} tests
${passes} passes
${failures} failures`);
  process.exit(failures ? 1 : 0);
}

main();
