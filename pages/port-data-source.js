const kleur = require("kleur");

module.exports =
/**
 * @param { unknown } fromElm
 * @returns { Promise<unknown> }
 */
{
    environmentVariable: async function (name) {
        const result = process.env[name];
        if (result) {
            return result;
        } else {
            throw `No environment variable called ${kleur
                .yellow()
                .underline(name)}\n\nAvailable:\n\n${Object.keys(process.env).join(
                    "\n"
                )}`;
        }
    },
    today: async function (arg) {
        return new Date().toISOString().split('T')[0];
    }
}