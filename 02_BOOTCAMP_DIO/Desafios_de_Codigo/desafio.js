// ============================================
// SIMULAÇÃO DO AMBIENTE DIO (só para teste local)
// ============================================
const _entrada = "https://web.dio.me/";   // ← troque aqui para testar cada caso
function gets() { return _entrada; }
function print(t) { console.log(t); }

// ============================================
// CÓDIGO ORIGINAL DA DIO (não alterar nada abaixo)
// ============================================
const url = gets();
var resultado;

if (url.startsWith("https://")) {
  resultado = "URL segura"

} else if (url.startsWith("http://")) {   // ← SUA IMPLEMENTAÇÃO
  resultado = "URL nao segura";           // ← SUA IMPLEMENTAÇÃO

} else {
  resultado = "Formato invalido";         // ← SUA IMPLEMENTAÇÃO
}
print(resultado);