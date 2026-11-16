import com.sun.source.tree.*;
import com.sun.source.util.JavacTask;
import java.util.List;
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

    public static void main(String[] args) throws Exception {
        if (args.length == 0) throw new IllegalArgumentException("Indica uno o mas archivos .java");
        var compiler = ToolProvider.getSystemJavaCompiler();
        var diagnostics = new javax.tools.DiagnosticCollector<javax.tools.JavaFileObject>();
        try (var files = compiler.getStandardFileManager(diagnostics, null, java.nio.charset.StandardCharsets.UTF_8)) {
            var task = (JavacTask) compiler.getTask(null, files, diagnostics, List.of("-proc:none"), null,
                files.getJavaFileObjectsFromStrings(List.of(args)));
            var units = task.parse();
            if (diagnostics.getDiagnostics().stream().anyMatch(d -> d.getKind() == javax.tools.Diagnostic.Kind.ERROR)) {
                diagnostics.getDiagnostics().forEach(System.err::println);
                System.exit(1);
            }
            System.out.println("```mermaid\nclassDiagram");
            for (var unit : units) {
                for (Tree declaration : unit.getTypeDecls()) {
                    if (declaration instanceof ClassTree type) diagram(type);
                }
            }
            System.out.println("```");
        }
    }
}
