describe('Navigation', () => {
  beforeEach(() => {
    cy.visit('https://fatihkoc.net')
  })

  it('should navigate to main pages', () => {
    cy.contains('About').click()
    cy.url().should('include', '/about/')
    cy.get('h1').should('contain', 'About')
    
    cy.contains('Blog').click()
    cy.url().should('include', '/posts/')
    cy.get('h1.title').should('be.visible')
    
    cy.contains('Contact').click()
    cy.url().should('include', '/contact/')
    cy.get('h1').should('contain', 'Contact')
  })
})
