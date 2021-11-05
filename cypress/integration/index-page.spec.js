context("index page", () => {
    beforeEach(() => {
        cy.visit("http://localhost:1234/");
    });

    it("found", () => {
        cy.contains("Top 10 Evictors");
    });
});