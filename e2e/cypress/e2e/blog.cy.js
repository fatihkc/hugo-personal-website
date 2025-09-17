describe('Blog Page', () => {
  beforeEach(() => {
    cy.visit('https://fatihkoc.net/posts/')
  })

  it('should load and display blog posts', () => {
    cy.url().should('include', '/posts/')
    cy.get('h1.title').should('be.visible')
    cy.get('ul li').should('have.length.at.least', 1)
    cy.get('ul li a.title').should('be.visible')
  })
})
