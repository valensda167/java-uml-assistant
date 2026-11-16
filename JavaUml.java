import com.sun.source.tree.*;
import com.sun.source.util.JavacTask;
import com.sun.source.util.TreeScanner;
import com.sun.source.util.Trees;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashSet;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import java.util.Set;
import javax.lang.model.element.Modifier;
import javax.tools.ToolProvider;

class JavaUml {
    static String visibility(Set<Modifier> flags) {
        if (flags.contains(Modifier.PUBLIC)) return "+";
        if (flags.contains(Modifier.PRIVATE)) return "-";
        if (flags.contains(Modifier.PROTECTED)) return "#";
        return "~";
    }

    static void diagram(ClassTree type) {
        String name = type.getSimpleName().toString();
        if (name.isEmpty()) return;
        System.out.println("    class " + name + " {");
        for (Tree member : type.getMembers()) {
            if (member instanceof VariableTree field && field.getType() != null) {
                System.out.println("        " + visibility(field.getModifiers().getFlags())
                    + field.getName() + " : " + field.getType().toString().replace("<", "~").replace(">", "~"));
            }
            if (member instanceof MethodTree method) {
                String parameters = String.join(", ", method.getParameters().stream()
                    .map(p -> p.getType().toString().replace("<", "~").replace(">", "~") + " " + p.getName()).toList());
                String label = method.getReturnType() == null ? name : method.getName().toString();
                String result = method.getReturnType() == null ? "" : " " + method.getReturnType().toString().replace("<", "~").replace(">", "~");
                System.out.println("        " + visibility(method.getModifiers().getFlags()) + label + "(" + parameters + ")" + result);
            }
        }
        System.out.println("    }");
        if (type.getExtendsClause() != null) {
            System.out.println("    " + simple(type.getExtendsClause()) + " <|-- " + name);
        }
        for (Tree parent : type.getImplementsClause()) {
            System.out.println("    " + simple(parent) + (type.getKind() == Tree.Kind.INTERFACE ? " <|-- " : " <|.. ") + name);
        }
    }

    static String simple(Tree type) {
        if (type instanceof ParameterizedTypeTree parameterized) return simple(parameterized.getType());
        return type instanceof MemberSelectTree qualified ? qualified.getIdentifier().toString() : type.toString();
    }

    static final Set<String> COLLECTIONS = Set.of(
        "List", "ArrayList", "LinkedList", "Set", "HashSet", "TreeSet",
        "Collection", "Queue", "Deque", "ArrayDeque", "Vector"
    );

    static void associations(ClassTree owner, Set<String> names) {
        for (Tree member : owner.getMembers()) {
            if (!(member instanceof VariableTree field) || field.getType() == null) continue;
            Tree target = field.getType();
            boolean many = false;
            if (target instanceof ArrayTypeTree array) {
                target = array.getType();
                many = true;
            } else if (target instanceof ParameterizedTypeTree generic
                       && COLLECTIONS.contains(simple(generic.getType()))
                       && generic.getTypeArguments().size() == 1) {
                target = generic.getTypeArguments().get(0);
                many = true;
            }
            String name = simple(target);
            if (!names.contains(name)) continue;
            String multiplicity = many ? "\"0..*\" " : "";
            System.out.println("    " + owner.getSimpleName() + " --> " + multiplicity + name
                + " : " + field.getName());
        }
    }

    static void testDependencies(ClassTree type, Set<String> names) {
        String test = type.getSimpleName().toString();
        if (!test.startsWith("Test")) return;
        Set<String> instances = new LinkedHashSet<>();
        for (Tree member : type.getMembers()) {
            if (!(member instanceof MethodTree method) || !method.getName().contentEquals("main")
                || !method.getModifiers().getFlags().containsAll(Set.of(Modifier.PUBLIC, Modifier.STATIC))) continue;
            new TreeScanner<Void, Void>() {
                @Override
                public Void visitNewClass(NewClassTree node, Void unused) {
                    String model = simple(node.getIdentifier());
                    if (names.contains(model) && !model.equals(test)) instances.add(model);
                    return super.visitNewClass(node, unused);
                }
            }.scan(method.getBody(), null);
        }
        for (String model : instances) {
            System.out.println("    " + test + " ..> " + model + " : crea");
        }
    }

    static void split(JavacTask task, Iterable<? extends CompilationUnitTree> units, Path out) throws Exception {
        var positions = Trees.instance(task).getSourcePositions();
        var types = new java.util.LinkedHashMap<String, String>();
        for (var unit : units) {
            String source = unit.getSourceFile().getCharContent(true).toString();
            String prefix = unit.getPackage() == null ? "" : unit.getPackage() + "\n";
            for (var declaration : unit.getImports()) prefix += declaration + "\n";
            for (Tree declaration : unit.getTypeDecls()) {
                if (!(declaration instanceof ClassTree type) || type.getSimpleName().length() == 0) continue;
                int start = (int) positions.getStartPosition(unit, type);
                int end = (int) positions.getEndPosition(unit, type);
                String name = type.getSimpleName().toString();
                String body = source.substring(start, end);
                if (types.putIfAbsent(name, prefix + "\n" + body) != null) {
                    throw new IllegalArgumentException("Tipo duplicado: " + name);
                }
            }
        }
        if (types.isEmpty()) throw new IllegalArgumentException("No hay declaraciones Java.");
        for (var entry : types.entrySet()) {
            String code = entry.getValue();
            String imports = "";
            for (String name : List.of("List", "ArrayList", "Map", "HashMap", "Set", "HashSet",
                    "Arrays", "Collections", "Scanner", "Objects", "LinkedList", "Optional")) {
                if (!types.containsKey(name) && code.matches("(?s).*\\b" + name + "\\b.*")
                    && !code.matches("(?s).*\\bimport\\s+[^;]*\\." + name + "\\s*;.*")
                    && !code.contains("import java.util.*;")) {
                    imports += "import java.util." + name + ";\n";
                }
            }
            int insertion = code.startsWith("package ") ? code.indexOf(';') + 1 : 0;
            Files.writeString(out.resolve(entry.getKey() + ".java"),
                code.substring(0, insertion) + "\n" + imports + code.substring(insertion) + "\n");
        }
    }

    public static void main(String[] args) throws Exception {
        if (args.length == 0) throw new IllegalArgumentException("Indica uno o mas archivos .java");
        boolean splitMode = args[0].equals("--split");
        Path out = splitMode ? Path.of(args[1]) : null;
        List<String> inputs = splitMode ? List.of(args).subList(2, args.length) : List.of(args);
        var compiler = ToolProvider.getSystemJavaCompiler();
        var diagnostics = new javax.tools.DiagnosticCollector<javax.tools.JavaFileObject>();
        try (var files = compiler.getStandardFileManager(diagnostics, null, java.nio.charset.StandardCharsets.UTF_8)) {
            var task = (JavacTask) compiler.getTask(null, files, diagnostics, List.of("-proc:none"), null,
                files.getJavaFileObjectsFromStrings(inputs));
            var units = task.parse();
            if (diagnostics.getDiagnostics().stream().anyMatch(d -> d.getKind() == javax.tools.Diagnostic.Kind.ERROR)) {
                diagnostics.getDiagnostics().forEach(System.err::println);
                System.exit(1);
            }
            if (splitMode) { split(task, units, out); return; }
            System.out.println("```mermaid\nclassDiagram");
            List<ClassTree> classes = new ArrayList<>();
            for (var unit : units) {
                for (Tree declaration : unit.getTypeDecls()) {
                    if (declaration instanceof ClassTree type && type.getSimpleName().length() > 0) classes.add(type);
                }
            }
            Set<String> names = classes.stream().map(type -> type.getSimpleName().toString())
                .collect(Collectors.toSet());
            classes.forEach(JavaUml::diagram);
            classes.forEach(type -> associations(type, names));
            classes.forEach(type -> testDependencies(type, names));
            System.out.println("```");
        }
    }
}



