// DEFAULT `(?:DEFAULT\s+([\w_]+))?`;
const tablePattern = r"CREATE\s+TABLE\s+([\w_]+)";
const columnsPattern = r"([\w_]+)[\s\w]+[,\n]";
// const columnsPattern = r"([\w_]+)[\s\w]+,";
// const primaryKeyPattern = r"\s*PRIMARY\s+KEY\s+\(([\w_]+)\)";
// const primaryKeyTopPattern = r"([\w_]+).*\sPRIMARY\sKEY";
// const primaryKeyBottomPattern = r"PRIMARY\sKEY\s+\(([^\)]+)\)";

// bottom
//PRIMARY\sKEY\s+\(([^\)]+)\)

// top
// ([\w_]+).*\sPRIMARY\sKEY

// (([\w_]+).*)\sPRIMARY\sKEY

const primaryKeysPattern =
    r"([\w_]+).*\sPRIMARY\sKEY|PRIMARY\sKEY\s+\(([^\)]+)\)";

// github
// const foreignKeyPattern =
//     r"FOREIGN KEY\s+\(([^\)]+)\)\s+REFERENCES\s+([^\(^\s]+)\s*\(([^\)]+)\)";

// stackoverflow
const foreignKeyPattern =
    r"\s*FOREIGN\s+KEY\s+\(([\w_]+)\)\s+REFERENCES\s+([\w_]+)\s+\(([\w_]+)\)";
const uniqueKeyPattern = r"/UNIQUE KEY\s+\`(.+)\`\s*\((\`.+\`)+\)/";
