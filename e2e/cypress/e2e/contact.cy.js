describe('Contact Page', () => {
  beforeEach(() => {
    cy.visit('https://fatihkoc.net/contact/')
  })

  it('should load the contact page successfully', () => {
    cy.url().should('include', '/contact/')
    cy.get('h1').should('contain', 'Contact')
  })
})
