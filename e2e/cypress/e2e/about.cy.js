describe('About Page', () => {
  beforeEach(() => {
    cy.visit('https://fatihkoc.net/about/')
  })

  it('should load the about page successfully', () => {
    cy.url().should('include', '/about/')
    cy.get('h1').should('contain', 'About')
    cy.get('img').should('be.visible')
  })
})
